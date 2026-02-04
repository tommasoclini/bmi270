use crate::ll::field_sets::{self, Acc, Gyr, SensorTime};

#[derive(Debug)]
pub enum FifoDataFrame<'a> {
    Reserved,
    Regular(RegularFrame<'a>),
    Control(ControlFrame<'a>),
}

#[derive(Debug)]
pub struct RegularFrame<'a> {
    pub aux: Option<&'a [u8]>,
    pub gyr: Option<&'a Gyr>,
    pub acc: Option<&'a Acc>,
}

impl<'a> RegularFrame<'a> {
    pub const fn empty() -> Self {
        Self {
            aux: None,
            gyr: None,
            acc: None,
        }
    }
}

#[derive(Debug)]
pub enum ControlFrame<'a> {
    SkipFrame(&'a u8),
    SensorTime(&'a field_sets::SensorTime),
    FifoInputConfig(&'a [u8; 4]),
}

/// Ok(bytes used), Err(where err is)
pub fn parse_fifo_data<'a>(
    data: &'a [u8],
    out: &mut impl Extend<FifoDataFrame<'a>>,
    aux: Option<usize>,
) -> Result<usize, usize> {
    let mut i = 0;
    loop {
        if i < data.len() {
            let f_kind = data[i];
            i += 1;
            match f_kind >> 6 {
                0b10 => {
                    let mut val = RegularFrame::empty();
                    if (f_kind & (1 << 4)) != 0 && data.len() - i >= 6 {
                        if let Some(s) = aux {
                            val.aux = Some(&data[i..i + s]);
                            i += s;
                        } else {
                            return Err(i);
                        }
                    };
                    if (f_kind & (1 << 3)) != 0 && data.len() - i >= 6 {
                        val.gyr = Some(unsafe { core::mem::transmute(&data[i]) });
                        i += 6;
                    }
                    if (f_kind & (1 << 2)) != 0 && data.len() - i >= 6 {
                        val.acc = Some(unsafe { core::mem::transmute(&data[i]) });
                        i += 6;
                    }

                    out.extend(Some(FifoDataFrame::Regular(val)));
                }
                0b01 => match (f_kind >> 2) & 0b111 {
                    0x0 if data.len() - i >= 1 => {
                        out.extend(Some(FifoDataFrame::Control(ControlFrame::SkipFrame(
                            &data[i],
                        ))));
                        i += size_of::<u8>();
                    }
                    0x1 if data.len() - i >= size_of::<SensorTime>() => {
                        out.extend(Some(FifoDataFrame::Control(ControlFrame::SensorTime(
                            unsafe { core::mem::transmute(&data[i]) },
                        ))));
                        i += size_of::<SensorTime>();
                    }
                    0x2 if data.len() - i >= 4 => {
                        out.extend(Some(FifoDataFrame::Control(ControlFrame::FifoInputConfig(
                            unsafe { core::mem::transmute(&data[i]) },
                        ))));
                        i += 4;
                    }
                    _ => return Err(i),
                },
                _ => return Err(i),
            }
        } else {
            return Ok(i);
        }
    }
}
