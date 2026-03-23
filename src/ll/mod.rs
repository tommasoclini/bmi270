#[cfg(test)]
mod test;

pub mod i2c;
pub mod spi;

device_driver::create_device!(
    device_name: Device,
    manifest: "src/ll/ll.yaml"
);

impl Into<usize> for AuxBurstLength {
    fn into(self) -> usize {
        aux_burst_length_to_usize(self)
    }
}

pub const fn aux_burst_length_to_usize(l: AuxBurstLength) -> usize {
    match l {
        AuxBurstLength::Bl1 => 1,
        AuxBurstLength::Bl2 => 2,
        AuxBurstLength::Bl6 => 6,
        AuxBurstLength::Bl8 => 8,
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[cfg_attr(feature = "defmt-03", derive(defmt::Format))]
pub enum DeviceError<T> {
    Interface(T),
    BufferTooSmall,
}

impl<T> From<T> for DeviceError<T> {
    fn from(value: T) -> Self {
        DeviceError::Interface(value)
    }
}
