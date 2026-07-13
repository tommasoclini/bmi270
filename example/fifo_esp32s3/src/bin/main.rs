#![no_std]
#![no_main]
#![deny(
    clippy::mem_forget,
    reason = "mem::forget is generally not safe to do with esp_hal types, especially those \
    holding buffers for the duration of a data transfer."
)]
#![deny(clippy::large_stack_frames)]

use core::fmt::Debug;

use alloc::string::{String, ToString};
use defmt::{Debug2Format, Display2Format, debug, info, trace, warn};
use embassy_executor::Spawner;
use embassy_futures::select::{Either, select};
use embassy_sync::blocking_mutex::raw::NoopRawMutex;
use embassy_sync::mutex::Mutex;
use embassy_time::{Duration, Ticker, Timer, with_timeout};
use esp_hal::clock::CpuClock;
use esp_hal::gpio::{Level, Output};
use esp_hal::ram;
use esp_hal::spi::master::Spi;
use esp_hal::timer::timg::TimerGroup;
use panic_rtt_target as _;

extern crate alloc;

// This creates a default app-descriptor required by the esp-idf bootloader.
// For more information see: <https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/system/app_image_format.html#application-description>
esp_bootloader_esp_idf::esp_app_desc!();

#[allow(
    clippy::large_stack_frames,
    reason = "it's not unusual to allocate larger buffers etc. in main"
)]
#[esp_rtos::main]
async fn main(_s: Spawner) -> ! {
    // generator version: 1.3.0
    // generator parameters: --chip esp32s3 -o esp32s3-mini-1-psram -o unstable-hal -o embassy -o probe-rs -o defmt -o panic-rtt-target -o neovim -o esp

    rtt_target::rtt_init_defmt!();

    let config = esp_hal::Config::default().with_cpu_clock(CpuClock::max());
    let p = esp_hal::init(config);

    // The following pins are used to bootstrap the chip. They are available
    // for use, but check the datasheet of the module for more information on them.
    // - GPIO0
    // - GPIO3
    // - GPIO45
    // - GPIO46
    // These GPIO pins are in use by some feature of the module and should not be used.
    let _ = p.GPIO26;
    let _ = p.GPIO27;
    let _ = p.GPIO28;
    let _ = p.GPIO29;
    let _ = p.GPIO30;
    let _ = p.GPIO31;
    let _ = p.GPIO32;

    let timg0 = TimerGroup::new(p.TIMG0);
    let sw_interrupt = esp_hal::interrupt::software::SoftwareInterruptControl::new(p.SW_INTERRUPT);
    esp_rtos::start(timg0.timer0, sw_interrupt.software_interrupt0);

    esp_alloc::heap_allocator!(#[ram(reclaimed)] size: 73744);

    info!("Embassy initialized!");

    let mut csb = Output::new(p.GPIO38, Level::High, Default::default());

    let iface = Spi::new(p.SPI2, Default::default())
        .unwrap()
        .with_mosi(p.GPIO36)
        .with_miso(p.GPIO35)
        .with_sck(p.GPIO37)
        .into_async();

    use bmi270::{hl, ll};
    debug!("imu has spi");
    let bus = Mutex::<NoopRawMutex, _>::new(iface);
    let dev = embassy_embedded_hal::shared_bus::asynch::spi::SpiDevice::new(&bus, &mut csb);

    let mut bmi = bmi270::ll::Device::new(bmi270::ll::spi::DeviceInterface::new(dev));

    loop {
        let mut op = async || -> Result<(), String> {
            pub fn dbg_to_string<T: Debug>(t: T) -> String {
                format_args!("{t:?}").to_string()
            }

            const TIMEOUT: Duration = Duration::from_millis(200);
            async fn lcl_timeout<F: Future>(f: F) -> Result<F::Output, embassy_time::TimeoutError> {
                with_timeout(TIMEOUT, f).await
            }

            fn reg_op_res<T, E: Debug>(
                res: Result<Result<T, E>, embassy_time::TimeoutError>,
                s: &'static str,
            ) -> Result<T, String> {
                conv_wtimeout_res(res.map(|r| r.map_err(dbg_to_string)))
                    .map_err(|e| format_args!("error {:?}, explanation: {}", e, s).to_string())
            }

            fn print_err<E: defmt::Format>(e: &E) {
                warn!("{}", e)
            }

            _ = lcl_timeout(bmi.chip_id().read_async()).await;
            Timer::after_millis(25).await;

            match lcl_timeout(bmi.chip_id().read_async()).await {
                Ok(Ok(val)) => {
                    if val.chip_id() == 0x24 {
                        debug!("chip id confirmed");
                    } else {
                        return Err(format_args!(
                            "chip id not confirmed, {:x} instead of 0x24",
                            val.chip_id()
                        )
                        .to_string());
                    }
                }
                e => return reg_op_res(e, "chip id confirmation failed").map(drop),
            };

            match lcl_timeout(bmi.cmd().write_async(|w| w.set_cmd(ll::Command::Softreset))).await {
                Ok(Ok(())) => {
                    debug!("soft reset sent")
                }
                e => return reg_op_res(e, "soft reset failed"),
            }

            Timer::after_millis(25).await;

            _ = lcl_timeout(bmi.chip_id().read_async()).await;

            Timer::after_millis(10).await;

            match lcl_timeout(bmi.pwr_conf().write_async(|w| {
                w.set_adv_power_save(false);
                w.set_fup_en(false);
                w.set_fifo_self_wake_up(false);
            }))
            .await
            {
                Ok(Ok(())) => {
                    debug!("set adv power save to false")
                }
                e => return reg_op_res(e, "failed to set adv power save: {e:?}"),
            }

            Timer::after_micros(450).await;

            match lcl_timeout(bmi.init_ctrl().write_async(|w| w.set_init_ctrl(0x00))).await {
                Ok(Ok(())) => {
                    debug!("set init ctrl to 0")
                }
                e => return reg_op_res(e, "failed to set init ctrl to 0"),
            }

            const CHUNK_SIZE: usize = 16;
            let mut addr = 0;
            for chunk in bmi270::config::BMI270_CONFIG_FILE.chunks(CHUNK_SIZE) {
                let res = lcl_timeout(bmi.init_addr().write_async(|w| {
                    let addr = (addr / 2) as u16;
                    w.set_init_addr_0((addr & 0x0F) as u8);
                    w.set_init_addr_1((addr >> 4) as u8);
                }))
                .await;
                reg_op_res(res, "failed to write addr of config chunk")?;

                reg_op_res(
                    lcl_timeout(bmi.init_data().write_async(chunk)).await,
                    "failed to write chunk",
                )?;

                addr += chunk.len();
            }

            debug!("config has been written");

            reg_op_res(
                lcl_timeout(bmi.init_ctrl().write_async(|w| w.set_init_ctrl(0x01))).await,
                "failed to tell imu to init",
            )?;

            debug!("told imu to init");

            Timer::after_millis(150).await;

            loop {
                match lcl_timeout(bmi.internal_status().read_async()).await {
                    Ok(Ok(internal_status)) => {
                        if internal_status.message() == ll::StatusMessage::InitOk {
                            break;
                        }
                    }
                    e => warn!("failed to read internal status: {:?}", Debug2Format(&e)),
                }

                Timer::after_millis(10).await;
            }

            reg_op_res(
                lcl_timeout(bmi.pwr_ctrl().modify_async(|w| {
                    w.set_acc_en(true);
                    w.set_gyr_en(true);
                }))
                .await,
                "failed to set pwr ctrl",
            )?;

            reg_op_res(
                lcl_timeout(bmi.acc_conf().modify_async(|w| {
                    w.set_acc_odr(ll::AccOdr::Odr200);
                    w.set_acc_bwp(ll::AccBwp::Osr4Avg1);
                    w.set_acc_filter_perf(ll::AccFilterPerf::Hlp)
                }))
                .await,
                "failed to configure accelerometer",
            )?;

            reg_op_res(
                lcl_timeout(bmi.gyr_conf().modify_async(|w| {
                    w.set_gyr_odr(ll::GyrOdr::Odr200);
                    w.set_gyr_bwp(ll::GyrBwp::Osr4);
                    w.set_gyr_noise_perf(ll::GyrNoisePerf::Hp);
                    w.set_gyr_filter_perf(ll::GyrFilterPerf::Hp);
                }))
                .await,
                "failed to configure gyro",
            )?;

            reg_op_res(
                lcl_timeout(bmi.fifo_config_1().modify_async(|w| {
                    w.set_fifo_acc_en(true);
                    w.set_fifo_gyr_en(true);
                }))
                .await,
                "failed to modify fifo_config_1",
            )?;

            debug!("starting reading process");

            let mut parser = hl::FrameParser::new(None);

            #[derive(Clone)]
            struct CompData {
                roll: f32,
                pitch: f32,
            }

            let comp = Mutex::<NoopRawMutex, _>::new(CompData {
                roll: 0.0,
                pitch: 0.0,
            });

            let Either::First(res) = select(
                async {
                    let mut ticker = Ticker::every(Duration::from_millis(50));
                    loop {
                        ticker.next().await;

                        let mut buf = [0; 256];
                        let Ok(length) = reg_op_res(
                            lcl_timeout(bmi.fifo_length().read_async()).await,
                            "failed to read fifo length",
                        )
                        .inspect_err(print_err) else {
                            continue;
                        };

                        let len = length.fifo_length() as usize;
                        if len == 0 {
                            continue;
                        }

                        trace!("fifo.length = {}", len);
                        let l = len.min(buf.len());
                        let Ok(size) = reg_op_res(
                            lcl_timeout(bmi.fifo_data().read_async(&mut buf[..l])).await,
                            "failed to read fifo data",
                        )
                        .inspect_err(print_err) else {
                            continue;
                        };

                        let mut start = 0;
                        loop {
                            match parser.feed(&buf[start..size]) {
                                Err(e) => {
                                    warn!("failed to parse fifo data: {:?}", e);
                                    _ = bmi
                                        .cmd()
                                        .write_async(|w| w.set_cmd(ll::Command::FifoFlush))
                                        .await
                                        .inspect_err(|e| warn!("failed to clear fifo data: {}", e));
                                    parser.reset();
                                    break;
                                }
                                Ok((n, f)) => {
                                    start += n;
                                    if let Some(frame) = f {
                                        if let hl::FifoDataFrame::Regular(hl::RegularFrame {
                                            acc: Some(acc_data),
                                            gyr: Some(gyr_data),
                                            ..
                                        }) = frame
                                        {
                                            const ACC_FSR: f32 = 8.0;
                                            const GYR_FSR: f32 = 2000.0;
                                            const I16_MAX_F32: f32 = i16::MAX as f32;
                                            const ACC_SCALE: f32 = ACC_FSR / I16_MAX_F32;
                                            const GYR_SCALE: f32 = GYR_FSR / I16_MAX_F32;

                                            let roll_rate = gyr_data.x() as f32 * GYR_SCALE;
                                            let pitch_rate = gyr_data.y() as f32 * GYR_SCALE;
                                            // let yaw_rate = gyr_data.z() as f32 * GYR_SCALE;

                                            let x_acc = acc_data.x() as f32 * ACC_SCALE;
                                            let y_acc = acc_data.y() as f32 * ACC_SCALE;
                                            let z_acc = acc_data.z() as f32 * ACC_SCALE;

                                            const RAD_TO_DEG: f32 = 180.0 / core::f32::consts::PI;

                                            let angle_roll = libm::atan2f(
                                                y_acc,
                                                libm::sqrtf(x_acc * x_acc + z_acc * z_acc),
                                            ) * RAD_TO_DEG;
                                            let angle_pitch = -libm::atan2f(
                                                x_acc,
                                                libm::sqrtf(y_acc * y_acc + z_acc * z_acc),
                                            ) * RAD_TO_DEG;

                                            const COMP_FILTER_GAIN: f32 = 0.98;
                                            /// inverse of the odr
                                            const T: f32 = 1.0 / 200.0;

                                            let mut comp = comp.lock().await;

                                            comp.roll = COMP_FILTER_GAIN
                                                * (comp.roll + roll_rate * T)
                                                + (1.0 - COMP_FILTER_GAIN) * angle_roll;

                                            comp.pitch = COMP_FILTER_GAIN
                                                * (comp.pitch + pitch_rate * T)
                                                + (1.0 - COMP_FILTER_GAIN) * angle_pitch;
                                        }
                                        parser.reset();
                                    }
                                }
                            }
                            if start == size {
                                break;
                            }
                        }
                    }
                },
                async {
                    let mut ticker = Ticker::every(Duration::from_hz(10));
                    loop {
                        let comp = comp.lock().await.clone();
                        info!(
                            "{}",
                            Display2Format(&format_args!(
                                "pitch: {:+2.2}, roll: {:+2.2}",
                                comp.pitch, comp.roll
                            ))
                        );
                        ticker.next().await;
                    }
                },
            )
            .await;
            res
        };
        match (op)().await {
            Ok(()) => {
                info!("finished imu op");
            }
            Err(e) => {
                warn!(
                    "failed op with error: {}, retrying in 5 seconds",
                    e.as_str()
                )
            }
        }
        Timer::after_secs(5).await;
    }

    // for inspiration have a look at the examples at https://github.com/esp-rs/esp-hal/tree/esp-hal-v1.1.0/examples
}

#[derive(Debug)]
enum MyTimeoutError<E> {
    Timeout(embassy_time::TimeoutError),
    Error(E),
}

fn conv_wtimeout_res<T, E>(
    res: Result<Result<T, E>, embassy_time::TimeoutError>,
) -> Result<T, MyTimeoutError<E>> {
    match res {
        Ok(Ok(v)) => Ok(v),
        Ok(Err(e)) => Err(MyTimeoutError::Error(e)),
        Err(e) => Err(MyTimeoutError::Timeout(e)),
    }
}

//
