device Device {
    byte-order: LE,
    register-address-type: u8,
    buffer-address-type: u8,
    word-boundaries: "_:-: :bB:A1:1A:1a:a1:AAa",

    /// Chip identification code
    register chip_id {
        address: 0,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Should be value 0x24
            field chip_id 7:0 RW -> uint,
        },
    },
    /// Reports sensor error conditions
    register err_reg {
        address: 2,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Fatal Error, chip is not in operational state (Boot-,
            /// power-system). This flag will be reset only by power-
            /// on-reset or softreset.
            field fatal_err 0 RW -> bool,
            /// Internal error, please contact your Bosch Sensortec regional support team.
            field internal_err 3:1 RW -> uint,
            /// Error when a frame is read in streaming mode (so
            /// skipping is not possible) and fifo is overfilled (with
            /// virtual and/or regular frames). This flag will be reset
            /// when read.
            field fifo_err 6 RW -> bool,
            /// Error in I2C-Master detected. This flag will be reset when read.
            field aux_err 7 RW -> bool,
        },
    },
    /// Sensor status flags
    register status {
        address: 3,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// '1'('0') indicate a (no) Auxiliary sensor interface operation
            /// is ongoing triggered via AUX_RD_ADDR,
            /// AUX_WR_ADDR or from FCU.
            field aux_busy 2 RW -> bool,
            /// CMD decoder status. '0' -> Command in progress '1' ->
            /// Command decoder is ready to accept a new command
            field cmd_rdy 4 RW -> bool,
            /// Data ready for Auxiliary sensor. It gets reset, when one
            /// Auxiliary sensor DATA register is read out
            field drdy_aux 5 RW -> bool,
            /// Data ready for Gyroscope. It gets reset, when one
            /// Gyroscope DATA register is read out
            field drdy_gyr 6 RW -> bool,
            /// Data ready for Accelerometer. It gets reset, when one
            /// Accelerometer DATA register is read out
            field drdy_acc 7 RW -> bool,
        },
    },
    /// Auxiliary sensor data
    register aux {
        address: 4,
        fields: fieldset _ {
            size-bytes: 8,
        
            field x 15:0 RW -> int,
            field y 31:16 RW -> int,
            field z 47:32 RW -> int,
            field r 63:48 RW -> int,
        },
    },
    /// Accelerometer data
    register acc {
        address: 12,
        fields: fieldset _ {
            size-bytes: 6,
        
            field x 15:0 RW -> int,
            field y 31:16 RW -> int,
            field z 47:32 RW -> int,
        },
    },
    /// Gyroscope data
    register gyr {
        address: 18,
        fields: fieldset _ {
            size-bytes: 6,
        
            field x 15:0 RW -> int,
            field y 31:16 RW -> int,
            field z 47:32 RW -> int,
        },
    },
    /// Sensor Time
    register sensor_time {
        address: 24,
        fields: fieldset _ {
            size-bytes: 3,
        
            field sensor_time 23:0 RW -> uint,
        },
    },
    /// Sensor event flags. Will be cleared on read when bit 0 is sent out over the bus.
    register event {
        address: 27,
        fields: fieldset _ {
            size-bytes: 1,
        
            field por_detected 0 RW -> bool,
            field error_code 3:2 RW -> uint as enum ErrorCode {
                /// No error is reported
                no_error: 0,
                /// Error in Register ACC_CONF
                acc_err: 1,
                /// Error in Register GYR_CONF
                gyr_err: 2,
                /// Error in Registers ACC_GYR & GYR_CONF
                acc_and_gyr_err: 3,
            },
        },
    },
    /// Interrupt/Feature Status. Will be cleared on read.
    register int_status_0 {
        address: 28,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Sigmotion output
            field sig_motion_out 0 RW -> bool,
            /// Step-counter watermark or Step-detector output
            field step_counter_out 1 RW -> bool,
            /// Step activity output
            field activity_out 2 RW -> bool,
            /// Wrist wear wakeup output
            field wrist_wear_wakeup_out 3 RW -> bool,
            /// Wrist gesture output
            field wrist_gesture_out 4 RW -> bool,
            /// No motion detection output
            field no_motion_out 5 RW -> bool,
            /// Any motion detection output
            field any_motion_out 6 RW -> bool,
        },
    },
    /// Interrupt Status 1. Will be cleared on read when bit 0 is sent out over the bus.
    register int_status_1 {
        address: 29,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// FIFO Full Interrupt
            field ffull_int 0 RW -> bool,
            /// FIFO Watermark Interrupt
            field fwm_int 1 RW -> bool,
            /// ERROR Interrupt
            field err_int 2 RW -> bool,
            /// Auxiliary Data Ready Interrupt
            field aux_drdy_int 5 RW -> bool,
            /// Gyroscope Data Ready Interrupt
            field gyr_drdy_int 6 RW -> bool,
            /// Accelerometer Data Ready Interrupt
            field acc_drdy_int 7 RW -> bool,
        },
    },
    /// Step counting value
    register sc_out {
        address: 30,
        fields: fieldset _ {
            size-bytes: 2,
        
            /// Step counter output value
            field step_count 15:0 RW -> uint,
        },
    },
    /// Wrist gesture and activity detection output
    register wr_gest_act {
        address: 32,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Output value of the wrist gesture detection
            /// feature. Value after device initialization is 0b00
            /// i.e. unknown gesture
            field wr_gest_out 2:0 RW -> uint as try enum WristGesture {
                /// Unknown gesture
                unknown_gesture: 0,
                /// Push arm down gesture
                push_arm_down: 1,
                /// Pivot up gesture
                pivot_up: 2,
                /// Wrist shake/jiggle gesture
                wrist_shake_jiggle: 3,
                /// Arm flick in gesture
                flick_in: 4,
                /// Arm flick out gesture
                flick_out: 5,
            },
            /// Output value of the activity detection feature.
            /// Value after device initialization is 0b11 i.e.
            /// unknown activity
            field act_out 4:3 RW -> uint as enum ActivityDetection {
                /// User stationary
                still: 0,
                /// User walking
                walking: 1,
                /// User running
                running: 2,
                /// Unknown state
                unknown: 3,
            },
        },
    },
    /// Error bits and message indicating internal status
    register internal_status {
        address: 33,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Internal Status Message
            field message 2:0 RW -> uint as enum StatusMessage {
                /// ASIC is not initialized
                not_init: 0,
                /// ASIC initialized
                init_ok: 1,
                /// Initialization error
                init_err: 2,
                /// Invalid driver
                drv_err: 3,
                /// Sensor stopped
                sns_stop: 4,
                /// Internal error while accessing NVM
                nvm_error: 5,
                /// Internal error while accessing NVM and Initialization error
                start_up_error: 6,
                /// Compatibility error
                compat_error: 7,
            },
            field axes_remap_error 5 RW -> bool,
            field odr_50hz_error 6 RW -> bool,
        },
    },
    /// Temperature data
    /// 
    /// The temperature is disabled when all sensors are in suspend. The output word of
    /// the 16-bit temperature sensor is valid if the Gyroscope is in normal mode, i.e. gyr_pmu_status=1.
    /// The resolution is 1/2^9 K/LSB. The absolute accuracy of the temperature is in the order of:
    /// * 0x7FFF -> 87-1/2^9 °C
    /// * 0x0000 -> 23°C
    /// * 0x8001 -> -41+1/2^9 °C
    /// * 0x8000 -> invalid
    /// If the Gyroscope is in normal mode (see register PMU_STATUS), the temperature is updated every 10 ms (+-
    /// 12%), if the gyroscope is in standby mode or fast-power up mode, the temperature is updated ever 1.28 s aligned with
    /// bit 15 of the register SENSORTIME.
    register temperature {
        address: 34,
        fields: fieldset _ {
            size-bytes: 2,
        
            field data 15:0 RW -> uint,
        },
    },
    register fifo_length {
        address: 36,
        fields: fieldset _ {
            size-bytes: 2,
        
            field fifo_length 13:0 RW -> uint,
        },
    },
    /// FIFO_DATA register
    buffer fifo_data {
        access: RW,
        address: 38,
    },
    
    register feat_page {
        address: 47,
        fields: fieldset _ {
            size-bytes: 1,

            field page 2:0 RW -> uint,
        },
    },

    /// Any-motion detection general configuration flags - part 1
    register any_motion1 {
        address: 60,
        reset: 57349,
        fields: fieldset _ {
            size-bytes: 2,
        
            field duration 12:0 RW -> uint,
            field select_x 13 RW -> bool,
            field select_y 14 RW -> bool,
            field select_z 15 RW -> bool,
        },
    },
    /// Any-motion detection general configuration flags - part 2
    register any_motion2 {
        address: 62,
        reset: 14506,
        fields: fieldset _ {
            size-bytes: 2,
        
            field threshold 10:0 RW -> uint,
            field out_conf 14:11 RW -> uint,
            /// Enables the feature
            field enable 15 RW -> bool,
        },
    },
    /// Power mode control register
    register acc_conf {
        address: 64,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// ODR in Hz. The output data rate is independent of
            /// the power mode setting for the sensor
            field acc_odr 3:0 RW -> uint as try enum acc_odr {
                /// 25/32Hz
                odr_0p78: 1,
                /// 25/16Hz
                odr_1p5: 2,
                /// 25/8Hz
                odr_3p1: 3,
                /// 25/4Hz
                odr_6p25: 4,
                /// 25/2Hz
                odr_12p5: 5,
                /// 25Hz
                odr_25: 6,
                /// 50Hz
                odr_50: 7,
                /// 100Hz
                odr_100: 8,
                /// 200Hz
                odr_200: 9,
                /// 400Hz
                odr_400: 10,
                /// 800Hz
                odr_800: 11,
                /// 1600Hz
                odr_1k6: 12,
            },
            /// Bandwidth parameter determines filter configuration
            /// (acc_filt_perf=1) and averaging for undersampling
            /// mode (acc_filt_perf=0)
            field acc_bwp 6:4 RW -> uint as enum acc_bwp {
                /// acc_filt_perf = 1 -> OSR4 mode; acc_filt_perf = 0 -> no averaging
                osr4_avg1: 0,
                /// acc_filt_perf = 1 -> OSR2 mode; acc_filt_perf = 0 -> average 2 samples
                osr2_avg2: 1,
                /// acc_filt_perf = 1 -> normal mode; acc_filt_perf = 0 -> average 4 samples
                norm_avg4: 2,
                /// acc_filt_perf = 1 -> CIC mode; acc_filt_perf = 0 -> average 8 samples
                cic_avg8: 3,
                /// acc_filt_perf = 1 -> Reserved; acc_filt_perf = 0 -> average 16 samples
                res_avg16: 4,
                /// acc_filt_perf = 1 -> Reserved; acc_filt_perf = 0 -> average 32 samples
                res_avg32: 5,
                /// acc_filt_perf = 1 -> Reserved; acc_filt_perf = 0 -> average 64 samples
                res_avg64: 6,
                /// acc_filt_perf = 1 -> Reserved; acc_filt_perf = 0 -> average 128 samples
                res_avg128: 7,
            },
            /// Select accelerometer filter performance mode
            field acc_filter_perf 7 RW -> uint as enum acc_filter_perf {
                /// Power optimized
                ulp: 0,
                /// Performance opt.
                hlp: 1,
            },
        },
    },
    /// Selection of the Accelerometer g-range
    register acc_range_reg {
        address: 65,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Accelerometer g-range
            field range_2g 1:0 RW -> uint as enum acc_range {
                /// +/-2g
                range_2g: 0,
                /// +/-2g
                range_4g: 1,
                /// +/-4g
                range_8g: 2,
                /// +/-16g
                range_16g: 3,
            },
        },
    },
    /// Sets the output data rate and the bandwidth of the Gyroscope
    register gyr_conf {
        address: 66,
        reset: 169,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// ODR in Hz
            field gyr_odr 3:0 RW -> uint as try enum gyr_odr {
                /// 25Hz
                odr_25: 6,
                /// 50Hz
                odr_50: 7,
                /// 100Hz
                odr_100: 8,
                /// 200Hz
                odr_200: 9,
                /// 400Hz
                odr_400: 10,
                /// 800Hz
                odr_800: 11,
                /// 1600Hz
                odr_1k6: 12,
                /// 3200Hz
                odr_3k2: 13,
            },
            /// Gyroscope bandwidth coefficient
            field gyr_bwp 5:4 RW -> uint as enum gyr_bwp {
                /// OSR4 mode
                osr4: 0,
                /// OSR2 mode
                osr2: 1,
                /// Normal mode
                norm: 2,
                /// Reserved
                res: 3,
            },
            /// Select noise performance
            field gyr_noise_perf 6 RW -> uint as enum gyr_noise_perf {
                /// Power optimized
                ulp: 0,
                /// Performance optimized
                hp: 1,
            },
            /// Select gyroscope filter performance mode
            field gyr_filter_perf 7 RW -> uint as enum gyr_filter_perf {
                /// Power optimized
                ulp: 0,
                /// Performance optimized
                hp: 1,
            },
        },
    },
    /// Defines the Gyroscope angular rate measurement range
    register gyr_range_reg {
        address: 67,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Full scale for filtered FIFO data and DATA registers
            field gyr_range 2:0 RW -> uint as try enum gyr_range {
                /// +/-2000dps, 16.4 LSB/dps
                range_2000: 0,
                /// +/-1000dps, 32.8 LSB/dps
                range_1000: 1,
                /// +/-500dps, 65.6 LSB/dps
                range_500: 2,
                /// +/-250dps, 131.2 LSB/dps
                range_250: 3,
                /// +/-125dps, 262.4 LSB/dps
                range_125: 4,
            },
            /// Full scale for pre-filtered FIFO data and OIS data
            field ois_range 3 RW -> uint as enum ois_range {
                /// +/-250dps, 131.2 LSB/dps
                range_250: 0,
                /// +/-2000dps, 16.4 LSB/dps
                range_2000: 1,
            },
        },
    },
    /// Sets the output data rate of the Auxiliary sensor interface
    register aux_conf {
        address: 68,
        reset: 70,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Poll rate for the magnetometer attached to the Auxiliary sensor interface
            field aux_odr 3:0 RW -> uint as try enum aux_odr {
                /// 25/32Hz
                odr_0p78: 1,
                /// 25/16Hz
                odr_1p5: 2,
                /// 25/8Hz
                odr_3p1: 3,
                /// 25/4Hz
                odr_6p25: 4,
                /// 25/2Hz
                odr_12p5: 5,
                /// 25Hz
                odr_25: 6,
                /// 50Hz
                odr_50: 7,
                /// 100Hz
                odr_100: 8,
                /// 200Hz
                odr_200: 9,
                /// 400Hz
                odr_400: 10,
                /// 800Hz
                odr_800: 11,
            },
            /// Trigger-readout offset in units of 2.5ms
            field aux_offset 7:4 RW -> uint,
        },
    },
    /// Configure Gyroscope and Accelerometer downsampling rates for FIFO
    register fifo_downs {
        address: 69,
        reset: 136,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Downsampling for Gyroscope (2**downs_gyro)
            field gyr_fifo_downs 2:0 RW -> uint,
            /// Selects filtered or unfiltered Gyroscope data for FIFO
            field gyr_fifo_filt_data 3 RW -> uint as enum fifo_filt_data {
                /// Unfiltered data
                unfiltered: 0,
                /// Filtered data
                filtered: 1,
            },
            /// Downsampling for Accelerometer (2**downs_accel)
            field acc_fifo_downs 6:4 RW -> uint,
            /// Selects filtered or unfiltered Accelerometer data for FIFO
            field acc_fifo_filt_data 7 RW -> uint as enum acc_fifo_filt_data {
                /// Unfiltered data
                unfiltered: 0,
                /// Filtered data
                filtered: 1,
            },
        },
    },
    /// FIFO Watermark level LSB
    register fifo_wtm_0 {
        address: 70,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Trigger interrupt when FIFO contains fifo_water_mark_7_0 + fifo_water_mark_12_8 * 256 bytes
            field fifo_water_mark_7_0 7:0 RW -> uint,
        },
    },
    /// FIFO Watermark level MSB
    register fifo_wtm_1 {
        address: 71,
        reset: 2,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Trigger interrupt when FIFO contains fifo_water_mark_7_0 + fifo_water_mark_12_8 * 256 bytes
            field fifo_water_mark_12_8 4:0 RW -> uint,
        },
    },
    /// FIFO frame content configuration
    register fifo_config_0 {
        address: 72,
        reset: 2,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Stop writing samples into FIFO when FIFO is full
            field fifo_stop_on_full 0 RW -> bool,
            /// Return sensortime frame after the last valid data frame
            field fifo_time_en 1 RW -> bool,
        },
    },
    /// FIFO frame content configuration
    register fifo_config_1 {
        address: 73,
        reset: 16,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// FIFO interrupt 1 tag enable
            field fifo_tag_int1_en 1:0 RW -> uint,
            /// FIFO interrupt 2 tag enable
            field fifo_tag_int2_en 3:2 RW -> uint,
            field fifo_header_en 4 RW -> bool,
            field fifo_aux_en 5 RW -> bool,
            field fifo_acc_en 6 RW -> bool,
            field fifo_gyr_en 7 RW -> bool,
        },
    },
    /// Contains information if raw data samples have been saturated
    register saturation {
        address: 74,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// ACC X-axis raw data saturation flag
            field acc_x 0 RW -> bool,
            /// ACC Y-axis raw data saturation flag
            field acc_y 1 RW -> bool,
            /// ACC Z-axis raw data saturation flag
            field acc_z 2 RW -> bool,
            /// GYR X-axis raw data saturation flag
            field gyr_x 3 RW -> bool,
            /// GYR Y-axis raw data saturation flag
            field gyr_y 4 RW -> bool,
            /// GYR Z-axis raw data saturation flag
            field gyr_z 5 RW -> bool,
        },
    },
    /// Auxiliary interface device_id
    register aux_dev_id {
        address: 75,
        reset: 32,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// I2C device address of Auxiliary sensor
            field i2c_device_addr 7:1 RW -> uint,
        },
    },
    /// Auxiliary interface configuration register
    register aux_if_conf {
        address: 76,
        reset: 131,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Burst data length
            field aux_rd_burst 1:0 RW -> uint as enum aux_burst_length {
                /// Burst length 1
                bl1: 0,
                /// Burst length 2
                bl2: 1,
                /// Burst length 6
                bl6: 2,
                /// Burst length 8
                bl8: 3,
            },
            /// Manual burst data length
            field man_rd_burst 3:2 RW -> uint as enum man_burst_length {
                /// Burst length 1
                bl1: 0,
                /// Burst length 2
                bl2: 1,
                /// Burst length 6
                bl6: 2,
                /// Burst length 8
                bl8: 3,
            },
            /// Enables FCU write command on AUX IF for auxiliary sensors that need a trigger
            field aux_fcu_write_en 6 RW -> bool,
            /// Switches auxiliary interface between automatic and manual mode
            field aux_manual_en 7 RW -> bool,
        },
    },
    /// Auxiliary interface read address
    register aux_rd_addr {
        address: 77,
        reset: 66,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Address to read. In manual mode it triggers the read operation
            field read_addr 7:0 RW -> uint,
        },
    },
    /// Auxiliary interface write address
    register aux_wr_addr {
        address: 78,
        reset: 76,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Address to write. In manual mode it triggers the write operation
            field write_addr 7:0 RW -> uint,
        },
    },
    /// Auxiliary interface write data
    register aux_wr_data {
        address: 79,
        reset: 2,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Data to write
            field write_data 7:0 RW -> uint,
        },
    },
    /// Defines which error flag will trigger the error interrupt
    register err_reg_msk {
        address: 82,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Use fatal error to generate the error interrupt
            field fatal_err 0 RW -> bool,
            /// Use internal error to generate the error interrupt
            field internal_err 4:1 RW -> uint,
            /// Use fifo error to generate the error interrupt
            field fifo_err 6 RW -> bool,
            /// Use aux interface error to generate the error interrupt
            field aux_err 7 RW -> bool,
        },
    },
    /// Configure the electrical behavior of the interrupt pin INT1
    register int1_io_ctrl {
        address: 83,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Configure output level of pin
            field lvl 1 RW -> uint as enum int_pin_level {
                active_low: 0,
                active_high: 1,
            },
            /// Configure output behaviour of pin
            field od 2 RW -> uint as enum int_pin_od {
                push_pull: 0,
                open_drain: 1,
            },
            /// Output enable for pin
            field output_en 3 RW -> bool,
            /// Input enable for pin
            field input_en 4 RW -> bool,
        },
    },
    /// Configure the electrical behavior of the interrupt pin INT2
    register int2_io_ctrl {
        address: 84,
        fields: int1_io_ctrl,
    },
    /// Configure interrupt latch modes
    register int_latch {
        address: 85,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Latched/non-latched interrupt modes
            field int_latch 0 RW -> uint as enum latch_mode {
                /// Non latched
                none: 0,
                /// Permanent latched
                permanent: 1,
            },
        },
    },
    /// Interrupt/Feature mapping on INT1
    register int1_map_feat {
        address: 86,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Sigmotion output
            field sig_motion_out 0 RW -> bool,
            /// Step-counter watermark or Step-detector output
            field step_counter_out 1 RW -> bool,
            /// Step activity output
            field activity_out 2 RW -> bool,
            /// Wrist wear wakeup output
            field wrist_wear_wakeup_out 3 RW -> bool,
            /// Wrist gesture output
            field wrist_gesture_out 4 RW -> bool,
            /// No motion detection output
            field no_motion_out 5 RW -> bool,
            /// Any motion detection output
            field any_motion_out 6 RW -> bool,
        },
    },
    /// Interrupt/Feature mapping on INT2
    register int2_map_feat {
        address: 87,
        fields: int1_map_feat,
    },
    /// Data Interrupt mapping of both INT pins
    register int_map_data {
        address: 88,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// FIFO Full interrupt mapped to INT1
            field ffull_int1 0 RW -> bool,
            /// FIFO Watermark interrupt mapped to INT1
            field fwm_int1 1 RW -> bool,
            /// Data Ready interrupt mapped to INT1
            field drdy_int1 2 RW -> bool,
            /// Error interrupt mapped to INT1
            field err_int1 3 RW -> bool,
            /// FIFO Full interrupt mapped to INT2
            field ffull_int2 4 RW -> bool,
            /// FIFO Watermark interrupt mapped to INT2
            field fwm_int2 5 RW -> bool,
            /// Data Ready interrupt mapped to INT2
            field drdy_int2 6 RW -> bool,
            /// Error interrupt mapped to INT2
            field err_int2 7 RW -> bool,
        },
    },
    /// Start initialization
    register init_ctrl {
        address: 89,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Start initialization
            field init_ctrl 7:0 RW -> uint,
        },
    },
    /// Base address of the initialization data. Increment by burst write length in bytes/2 after each burst write
    /// operation. Please ignore, if your host supports to load the initialization data in a single 8kB burst write operation.
    register init_addr {
        address: 91,
        fields: fieldset _ {
            size-bytes: 2,
        
            /// Base address for initialization data
            field init_addr0 3:0 RW -> uint,
            /// Base address for initialization data
            field init_addr1 15:8 RW -> uint,
        },
    },
    /// Register for initialization data
    buffer init_data {
        access: RW,
        address: 94,
    },
    /// Internal error flags
    register internal_error {
        address: 95,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Internal error flag - long processing time, processing halted
            field int_err_1 1 RW -> bool,
            /// Internal error flag - fatal error, processing halted
            field int_err_2 2 RW -> bool,
            /// Feature engine has been disabled by host during sensor operation
            field feat_eng_disabled 4 RW -> bool,
        },
    },
    /// Auxiliary interface trim register (NVM backed)
    register aux_if_trim {
        address: 104,
        reset: 1,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Pullup configuration for ASDA
            field asda_pupsel 1:0 RW -> uint as enum asda_pullup {
                /// Pullup off
                pup_res_off: 0,
                /// Pullup 40k
                pup_res_40k: 1,
                /// Pullup 10k
                pup_res_10k: 2,
                /// Pullup 2k
                pup_res_2k: 3,
            },
        },
    },
    /// Component Retrimming for Gyroscope
    register gyr_crt_conf {
        address: 105,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Indicates that CRT is currently running
            field crt_running 2 RW -> uint as enum crt_running {
                /// Disabled
                disabled: 0,
                /// Enabled
                enabled: 1,
            },
            /// Pacemaker bit for downloading the CRT data
            field rdy_for_dl 3 RW -> uint as enum rdy_for_dl {
                /// Ongoing or not started
                ongoing: 0,
                /// Complete
                complete: 1,
            },
        },
    },
    /// NVM Configuration
    register nvm_conf {
        address: 106,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Enable NVM programming
            field nvm_prog_en 1 RW -> uint as enum nvm_prog_en {
                /// Disable
                disable: 0,
                /// Enable
                enable: 1,
            },
        },
    },
    /// Serial interface settings
    register if_conf {
        address: 107,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Configure SPI Interface Mode for primary interface
            field spi3 0 RW -> uint as enum spi_mode {
                /// SPI 4-wire mode
                spi4: 0,
                /// SPI 3-wire mode
                spi3: 1,
            },
            /// Configure SPI Interface Mode for OIS interface
            field spi3_ois 1 RW -> uint as enum spi_mode_ois {
                /// SPI 4-wire mode
                spi4: 0,
                /// SPI 3-wire mode
                spi3: 1,
            },
            /// Interface configuration - OIS enable bit
            field ois_en 4 RW -> bool,
            /// Interface configuration - AUX enable bit
            field aux_en 5 RW -> bool,
        },
    },
    /// Drive strength control register (NVM backed)
    register drv {
        address: 108,
        reset: 170,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Output pad drive strength setting for the SDO and SDx pins
            field io_pad_drv1 2:0 RW -> uint,
            /// Disable additional pull down strength of SDx pin in I2C mode
            field io_pad_iic_b1 3 RW -> bool,
            /// Output pad drive strength setting for OSDO, ASCx, and ASDx pins
            field io_pad_drv2 6:4 RW -> uint,
            /// Disable additional pull down strength of ASCx and ASDx pins in I2C mode
            field io_pad_iic_b2 7 RW -> bool,
        },
    },
    /// Settings for the accelerometer self-test configuration and trigger
    register acc_self_test {
        address: 109,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Enable accelerometer self-test
            field acc_self_test_en 0 RW -> uint as enum acc_self_test_en {
                /// Disabled
                disabled: 0,
                /// Enabled
                enabled: 1,
            },
            /// Select sign of self-test excitation
            field acc_self_test_sign 2 RW -> uint as enum acc_self_test_sign {
                /// Negative
                negative: 0,
                /// Positive
                positive: 1,
            },
            /// Select amplitude of the selftest deflection
            field acc_self_test_amp 3 RW -> uint as enum acc_self_test_amp {
                /// Low
                low: 0,
                /// High
                high: 1,
            },
        },
    },
    /// Settings for the gyroscope AXES self-test configuration and trigger
    register gyr_self_test_axes {
        address: 110,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// STATUS - functional test of detection channels finished
            field gyr_st_axes_done 0 RW -> bool,
            /// Status of gyro X-axis self test
            field gyr_axis_x_ok 1 RW -> bool,
            /// Status of gyro Y-axis self test
            field gyr_axis_y_ok 2 RW -> bool,
            /// Status of gyro Z-axis self test
            field gyr_axis_z_ok 3 RW -> bool,
        },
    },
    /// NVM backed configuration bits
    register nv_conf {
        address: 112,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Disable I2C and enable SPI for primary interface
            field spi_en 0 RW -> uint as enum spi_en {
                /// I2C enabled
                disabled: 0,
                /// I2C disabled
                enabled: 1,
            },
            /// Select timer period for I2C Watchdog
            field i2c_wdt_sel 1 RW -> uint as enum i2c_wdt_sel {
                /// I2C watchdog timeout after 1.25ms
                short: 0,
                /// I2C watchdog timeout after 40ms
                long: 1,
            },
            /// I2C Watchdog at the SDA pin in I2C interface mode
            field i2c_wdt_en 2 RW -> uint as enum i2c_wdt_en {
                /// Disable I2C watchdog
                disable: 0,
                /// Enable I2C watchdog
                enable: 1,
            },
            /// Add offset to filtered and unfiltered Accelerometer data
            field acc_off_en 3 RW -> uint as enum acc_off_en {
                /// Disabled
                disabled: 0,
                /// Enabled
                enabled: 1,
            },
        },
    },
    /// Offset compensation for Accelerometer X-axis (NVM backed)
    register offset_0 {
        address: 113,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Accelerometer offset compensation (X-axis)
            field off_acc_x 7:0 RW -> uint,
        },
    },
    /// Offset compensation for Accelerometer Y-axis (NVM backed)
    register offset_1 {
        address: 114,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Accelerometer offset compensation (Y-axis)
            field off_acc_y 7:0 RW -> uint,
        },
    },
    /// Offset compensation for Accelerometer Z-axis (NVM backed)
    register offset_2 {
        address: 115,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Accelerometer offset compensation (Z-axis)
            field off_acc_z 7:0 RW -> uint,
        },
    },
    /// Offset compensation for Gyroscope X-axis (NVM backed)
    register offset_3 {
        address: 116,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Gyroscope offset compensation (X-axis)
            field gyr_usr_off_x_7_0 7:0 RW -> uint,
        },
    },
    /// Offset compensation for Gyroscope Y-axis (NVM backed)
    register offset_4 {
        address: 117,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Gyroscope offset compensation (Y-axis)
            field gyr_usr_off_y_7_0 7:0 RW -> uint,
        },
    },
    /// Offset compensation for Gyroscope Z-axis (NVM backed)
    register offset_5 {
        address: 118,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Gyroscope offset compensation (Z-axis)
            field gyr_usr_off_z_7_0 7:0 RW -> uint,
        },
    },
    /// Offset compensation (MSBs gyroscope, enables) (NVM backed)
    register offset_6 {
        address: 119,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Gyroscope offset compensation (X-axis)
            field gyr_usr_off_x_9_8 1:0 RW -> uint,
            /// Gyroscope offset compensation (Y-axis)
            field gyr_usr_off_y_9_8 3:2 RW -> uint,
            /// Gyroscope offset compensation (Z-axis)
            field gyr_usr_off_z_9_8 5:4 RW -> uint,
            /// Add offset to filtered and unfiltered Gyroscope data
            field gyr_off_en 6 RW -> uint as enum gyr_off_en {
                /// Disabled
                disabled: 0,
                /// Enabled
                enabled: 1,
            },
            /// Compensate the gain as described in Sensitivity Error Compensation
            field gyr_gain_en 7 RW -> uint as enum gyr_gain_en {
                /// Disabled
                disabled: 0,
                /// Enabled
                enabled: 1,
            },
        },
    },
    /// Power mode configuration register
    register pwr_conf {
        address: 124,
        reset: 3,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Advanced power mode enabled
            field adv_power_save 0 RW -> bool,
            /// FIFO read enabled in low power mode after FIFO interrupt is fired
            field fifo_self_wake_up 1 RW -> bool,
            /// Fast power up enabled
            field fup_en 2 RW -> bool,
        },
    },
    /// Power mode control register
    register pwr_ctrl {
        address: 125,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Enables the Auxiliary sensor
            field aux_en 0 RW -> bool,
            /// Enables the Gyroscope
            field gyr_en 1 RW -> bool,
            /// Enables the Accelerometer
            field acc_en 2 RW -> bool,
            /// Enables the Temperature sensor
            field temp_en 3 RW -> bool,
        },
    },
    /// Command register
    register cmd {
        address: 126,
        fields: fieldset _ {
            size-bytes: 1,
        
            /// Executes a command
            field cmd 7:0 RW -> uint as try enum Command {
                /// Trigger special gyro operations
                g_trigger: 2,
                /// Applies new gyro gain value
                usr_gain: 3,
                /// Writes the NVM backed registers into NVM
                nvm_prog: 160,
                /// Clears FIFO content
                fifo_flush: 176,
                /// Triggers a reset, all user configuration
                /// settings are overwritten with their
                /// default state
                softreset: 182,
            },
        },
    },
}
