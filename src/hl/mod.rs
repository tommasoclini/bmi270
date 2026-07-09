use core::num::NonZeroU8;

use heapless::Vec;

use crate::ll::{
    AuxBurstLength,
    field_sets::{Acc, Gyr, SensorTime},
};

#[derive(Debug)]
pub enum FifoDataFrame {
    Reserved,
    Regular(RegularFrame),
    Control(ControlFrame),
}

#[derive(Debug)]
pub struct RegularFrame {
    pub aux: Option<[u8; 8]>,
    pub gyr: Option<Gyr>,
    pub acc: Option<Acc>,
}

pub const AUX_BURST_DATA_MAX_LEN: usize = 8;

impl RegularFrame {
    pub const fn empty() -> Self {
        Self {
            aux: None,
            gyr: None,
            acc: None,
        }
    }
}

#[derive(Debug)]
pub enum ControlFrame {
    SkipFrame(u8),
    SensorTime(SensorTime),
    FifoInputConfig(FifoInputConfig),
}

pub type FifoInputConfig = [u8; 4];

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
        aux: Option<Vec<u8, { AUX_BURST_DATA_MAX_LEN }, u8>>,
        gyr: Option<Vec<u8, { size_of::<Gyr>() }, u8>>,
        acc: Option<Vec<u8, { size_of::<Acc>() }, u8>>,
    },
    Control {
        kind: ControlFrameKind,
        data: Vec<u8, 4, u8>,
    },
}

pub struct FrameParser {
    state: FrameParserState,
    aux: Option<NonZeroU8>,
}

#[derive(Debug)]
pub struct ParsingError;

impl FrameParser {
    pub fn new(aux: Option<AuxBurstLength>) -> Self {
        Self {
            state: FrameParserState::Kind,
            aux: aux.map(Into::into),
        }
    }

    /// must be called before starting to parse a new frame
    pub fn reset(&mut self) {
        self.state = FrameParserState::Kind;
    }

    /// feeds a slice of data to the parser, returns how many bytes were used.
    /// this means that unused bytes must be fed again for a new frame,
    /// this mechanism goes well with BufRead.
    pub fn feed(&mut self, data: &[u8]) -> Result<(usize, Option<FifoDataFrame>), ParsingError> {
        let mut i = 0;
        for b in data {
            self.push(*b)?;
            i += 1;
            if self.frame_ready() {
                break;
            }
        }
        Ok((i, self.try_frame()))
    }

    /// checks if a frame can be constructed from state
    pub fn frame_ready(&self) -> bool {
        match &self.state {
            FrameParserState::Kind => false,
            FrameParserState::Regular { aux, gyr, acc } => {
                let mut aux_done = true;
                let mut gyr_done = true;
                let mut acc_done = true;

                if let Some(v) = aux
                    && let Some(len) = self.aux
                    && v.len() < len.get() as usize
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

    /// tries creating a frame from parser state
    pub fn try_frame(&self) -> Option<FifoDataFrame> {
        match &self.state {
            FrameParserState::Kind => None,
            FrameParserState::Regular { aux, gyr, acc } => {
                Some(FifoDataFrame::Regular(RegularFrame {
                    aux: aux.as_ref().map(|val| {
                        let mut buf = [0; AUX_BURST_DATA_MAX_LEN];
                        buf[..val.len()].copy_from_slice(val.as_slice());
                        buf
                    }),
                    gyr: if let Some(v) = gyr
                        && v.is_full()
                    {
                        Some(*unsafe { &*v.as_ptr().cast() })
                    } else {
                        None
                    },
                    acc: if let Some(v) = acc
                        && v.is_full()
                    {
                        Some(*unsafe { &*v.as_ptr().cast() })
                    } else {
                        None
                    },
                }))
            }
            FrameParserState::Control { kind, data } => {
                if data.len() == kind.len() {
                    Some(FifoDataFrame::Control(match kind {
                        ControlFrameKind::SkipFrame => {
                            ControlFrame::SkipFrame(*unsafe { &*data.as_ptr().cast() })
                        }
                        ControlFrameKind::SensorTime => {
                            ControlFrame::SensorTime(*unsafe { &*data.as_ptr().cast() })
                        }
                        ControlFrameKind::FifoInputConfig => {
                            ControlFrame::FifoInputConfig(*unsafe { &*data.as_ptr().cast() })
                        }
                    }))
                } else {
                    None
                }
            }
        }
    }

    /// pushes a single byte and returns wether parsing going ok
    fn push(&mut self, b: u8) -> Result<(), ParsingError> {
        match &mut self.state {
            state @ FrameParserState::Kind => {
                *state = match b >> 6 {
                    0b10 => {
                        // regular
                        FrameParserState::Regular {
                            aux: (b & (1 << 4) != 0).then(Vec::new),
                            gyr: (b & (1 << 3) != 0).then(Vec::new),
                            acc: (b & (1 << 2) != 0).then(Vec::new),
                        }
                    }
                    0b01 => {
                        // control
                        FrameParserState::Control {
                            kind: match (b >> 2) & 0b111 {
                                0x0 => ControlFrameKind::SkipFrame,
                                0x1 => ControlFrameKind::SensorTime,
                                0x2 => ControlFrameKind::FifoInputConfig,
                                _ => return Err(ParsingError),
                            },
                            data: Vec::new(),
                        }
                    }
                    _ => return Err(ParsingError),
                };
            }
            FrameParserState::Regular { aux, gyr, acc } => {
                if let Some(v) = aux
                    && let Some(len) = self.aux
                    && (len.get() as usize) < v.len()
                {
                    _ = v.push(b);
                } else if let Some(v) = gyr
                    && !v.is_full()
                {
                    _ = v.push(b);
                } else if let Some(v) = acc
                    && !v.is_full()
                {
                    _ = v.push(b);
                }
            }
            FrameParserState::Control { kind, data } => {
                if data.len() < kind.len() {
                    _ = data.push(b);
                }
            }
        };
        Ok(())
    }
}
