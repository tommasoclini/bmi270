use device_driver::FieldsetMetadata;
use embedded_hal::spi::Operation;
use embedded_hal_async::spi::SpiDevice;

use crate::ll::DeviceError;

pub struct DeviceInterface<SPI: SpiDevice> {
    spi: SPI,
}

impl<SPI: SpiDevice> DeviceInterface<SPI> {
    /// Construct a new instance of the device.
    ///
    /// SPI max frequency 10MHz.
    pub const fn new(spi: SPI) -> Self {
        Self { spi }
    }
}

impl<SPI: SpiDevice> device_driver::RegisterInterfaceBase for DeviceInterface<SPI> {
    type Error = DeviceError<SPI::Error>;

    type AddressType = u8;
}

impl<SPI: SpiDevice> device_driver::AsyncRegisterInterface for DeviceInterface<SPI> {
    async fn write_register(
        &mut self,
        address: Self::AddressType,
        data: &mut [u8],
        _metadata: &FieldsetMetadata,
    ) -> Result<(), Self::Error> {
        let preamble = [address];
        let mut operations = [Operation::Write(&preamble), Operation::Write(data)];
        Ok(self.spi.transaction(&mut operations).await?)
    }

    async fn read_register(
        &mut self,
        address: Self::AddressType,
        data: &mut [u8],
        _metadata: &FieldsetMetadata,
    ) -> Result<(), Self::Error> {
        // Write address with read bit, and dummy byte to give the chip time to fetch the data
        let preamble = [address | 0b1000_0000, 0x00];
        let mut operations = [Operation::Write(&preamble), Operation::Read(data)];
        Ok(self.spi.transaction(&mut operations).await?)
    }
}

impl<SPI: SpiDevice> device_driver::BufferInterfaceBase for DeviceInterface<SPI> {
    type Error = DeviceError<SPI::Error>;

    type AddressType = u8;
}

impl<SPI: SpiDevice> device_driver::AsyncBufferInterface for DeviceInterface<SPI> {
    async fn write(
        &mut self,
        address: Self::AddressType,
        buf: &[u8],
    ) -> Result<usize, Self::Error> {
        let preamble = [address];
        let mut operations = [Operation::Write(&preamble), Operation::Write(buf)];
        self.spi.transaction(&mut operations).await?;

        Ok(buf.len())
    }

    async fn flush(&mut self, address: Self::AddressType) -> Result<(), Self::Error> {
        // No-op
        let _ = address;
        Ok(())
    }

    async fn read(
        &mut self,
        address: Self::AddressType,
        buf: &mut [u8],
    ) -> Result<usize, Self::Error> {
        // Write address with read bit, and dummy byte to give the chip time to fetch the data
        let preamble = [address | 0b1000_0000, 0x00];
        let mut operations = [Operation::Write(&preamble), Operation::Read(buf)];
        self.spi.transaction(&mut operations).await?;
        Ok(buf.len())
    }
}
