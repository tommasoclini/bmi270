use core::mem::transmute;

use heapless::Vec;

use crate::ll::{
    AuxBurstLength, aux_burst_length_to_usize,
    field_sets::{Acc, Gyr, SensorTime},
};

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
    SensorTime(&'a SensorTime),
    FifoInputConfig(&'a [u8; 4]),
}

enum ControlFrameKind {
    SkipFrame,
    SensorTime,
    FifoInputConfig,
}

impl ControlFrameKind {
    const fn len(&self) -> usize {
        match self {
            Self::SkipFrame => 1,
            Self::SensorTime => 3,
            Self::FifoInputConfig => 4,
        }
    }
}

enum FrameParserState {
    Kind,
    Regular {
        aux: Option<Vec<u8, 8>>,
        gyr: Option<Vec<u8, { size_of::<Gyr>() }>>,
        acc: Option<Vec<u8, { size_of::<Acc>() }>>,
    },
    Control {
        kind: ControlFrameKind,
        data: Vec<u8, 4>,
    },
}

pub struct FrameParser {
    state: FrameParserState,
    aux: Option<usize>,
}

struct Dropper<T>(pub T);

impl<T> Dropper<T> {
    pub fn get(self) -> T {
        self.0
    }
}

impl FrameParser {
    pub const fn new(aux: Option<AuxBurstLength>) -> Self {
        Self {
            state: FrameParserState::Kind,
            aux: if let Some(aux) = aux {
                Some(aux_burst_length_to_usize(aux))
            } else {
                None
            },
        }
    }

    pub fn reset(&mut self) {
        self.state = FrameParserState::Kind;
    }

    pub fn feed(&mut self, data: &[u8]) -> Result<(usize, Option<FifoDataFrame<'_>>), ()> {
        let mut i = 0;
        for b in data {
            self.push(Dropper(*b))?;
            i += 1;
            if self.frame_ready() {
                break;
            }
        }
        Ok((i, self.try_frame()))
    }

    pub fn frame_ready(&self) -> bool {
        match &self.state {
            FrameParserState::Kind => false,
            FrameParserState::Regular { aux, gyr, acc } => {
                let mut aux_done = true;
                let mut gyr_done = true;
                let mut acc_done = true;

                if let Some(v) = aux
                    && let Some(len) = self.aux
                    && len != v.len()
                {
                    aux_done = false;
                } else if let Some(v) = gyr
                    && !v.is_full()
                {
                    gyr_done = false;
                } else if let Some(v) = acc
                    && !v.is_full()
                {
                    acc_done = false;
                }
                aux_done && gyr_done && acc_done
            }
            FrameParserState::Control { kind, data } => data.len() == kind.len(),
        }
    }

    pub fn try_frame(&self) -> Option<FifoDataFrame<'_>> {
        match &self.state {
            FrameParserState::Kind => None,
            FrameParserState::Regular { aux, gyr, acc } => {
                Some(FifoDataFrame::Regular(RegularFrame {
                    aux: aux.as_ref().map(Vec::as_slice),
                    gyr: if let Some(v) = gyr
                        && v.is_full()
                        && let Some(f) = v.first()
                    {
                        Some(unsafe { transmute(f) })
                    } else {
                        None
                    },
                    acc: if let Some(v) = acc
                        && v.is_full()
                        && let Some(f) = v.first()
                    {
                        Some(unsafe { transmute(f) })
                    } else {
                        None
                    },
                }))
            }
            FrameParserState::Control { kind, data } => {
                if data.len() == kind.len() {
                    data.first().map(|f| {
                        FifoDataFrame::Control(match kind {
                            ControlFrameKind::SkipFrame => ControlFrame::SkipFrame(f),
                            ControlFrameKind::SensorTime => {
                                ControlFrame::SensorTime(unsafe { transmute(f) })
                            }
                            ControlFrameKind::FifoInputConfig => {
                                ControlFrame::FifoInputConfig(unsafe { transmute(f) })
                            }
                        })
                    })
                } else {
                    None
                }
            }
        }
    }

    fn push(&mut self, b: Dropper<u8>) -> Result<(), ()> {
        Ok(match &mut self.state {
            state @ FrameParserState::Kind => {
                let b = b.get();
                *state = match b >> 6 {
                    0b10 => {
                        // regular
                        FrameParserState::Regular {
                            aux: (b & (1 << 4) != 0).then_some(Vec::new()),
                            gyr: (b & (1 << 3) != 0).then_some(Vec::new()),
                            acc: (b & (1 << 2) != 0).then_some(Vec::new()),
                        }
                    }
                    0b01 => {
                        // control
                        FrameParserState::Control {
                            kind: match (b >> 2) & 0b111 {
                                0x0 => ControlFrameKind::SkipFrame,
                                0x1 => ControlFrameKind::SensorTime,
                                0x2 => ControlFrameKind::FifoInputConfig,
                                _ => return Err(()),
                            },
                            data: Vec::new(),
                        }
                    }
                    _ => return Err(()),
                };
            }
            FrameParserState::Regular { aux, gyr, acc } => {
                if let Some(v) = aux
                    && let Some(len) = self.aux
                    && len != v.len()
                {
                    _ = v.push(b.get());
                } else if let Some(v) = gyr
                    && !v.is_full()
                {
                    _ = v.push(b.get());
                } else if let Some(v) = acc
                    && !v.is_full()
                {
                    _ = v.push(b.get());
                }
            }
            FrameParserState::Control { kind, data } => {
                if data.len() != kind.len() {
                    _ = data.push(b.get());
                }
            }
        })
    }
}
