use core::num::NonZeroU8;

#[cfg(test)]
mod test;

pub mod i2c;
pub mod spi;

device_driver::compile!(
    options: "--rust-defmt-feature=defmt",
    manifest: "src/ll/ll.ddl"
);

impl From<AuxBurstLength> for NonZeroU8 {
    fn from(value: AuxBurstLength) -> Self {
        match value {
            AuxBurstLength::Bl1 => Self::new(1).unwrap(),
            AuxBurstLength::Bl2 => Self::new(2).unwrap(),
            AuxBurstLength::Bl6 => Self::new(6).unwrap(),
            AuxBurstLength::Bl8 => Self::new(8).unwrap(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[cfg_attr(feature = "defmt", derive(defmt::Format))]
pub enum DeviceError<T> {
    Interface(T),
    BufferTooSmall,
}

impl<T> From<T> for DeviceError<T> {
    fn from(value: T) -> Self {
        DeviceError::Interface(value)
    }
}
