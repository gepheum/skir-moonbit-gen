pub struct Timestamp {
  unix_millis : Int64
}

let min_timestamp_millis : Int64 = -8640000000000000L
let max_timestamp_millis : Int64 = 8640000000000000L

pub fn clamp_timestamp_millis(ms : Int64) -> Int64 {
  if ms < min_timestamp_millis {
    min_timestamp_millis
  } else if ms > max_timestamp_millis {
    max_timestamp_millis
  } else {
    ms
  }
}

pub fn timestamp_from_unix_millis(ms : Int64) -> Timestamp {
  { unix_millis: clamp_timestamp_millis(ms) }
}

pub fn Timestamp::to_unix_millis(self : Timestamp) -> Int64 {
  self.unix_millis
}
