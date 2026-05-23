pub fn bool_serializer() -> Serializer[Bool] {
  new_serializer({
    is_default: fn(input : Bool) { !input },
    to_dense_json: fn(input : Bool, builder : StringBuilder) {
      builder.write_string(if input { "1" } else { "0" })
    },
    to_readable_json: fn(input : Bool) {
      parse_json(if input { "true" } else { "false" })
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::True => Ok(true)
        Json::False => Ok(false)
        Json::Number(n, ..) => Ok(n.to_int() != 0)
        Json::String(s) => Ok(s != "0")
        _ => Ok(false)
      }
    },
    encode: fn(input : Bool, out : OutputStream) {
      if input {
        output_stream_write_int(out, 1)
      } else {
        output_stream_write_int(out, 0)
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match input_stream_read_int(input) {
        Ok((b, _tail)) => Ok(b != 0)
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Bool),
        records: [],
      }
    },
  })
}

let max_safe_int64_json : Int64 = 9007199254740991L
let max_safe_hash64_json : UInt64 = 9007199254740991UL

fn parse_json(code : String) -> Json {
  try {
    @json.parse(code)
  } catch {
    _ => panic()
  }
}

fn hex_digit(n : Int) -> Char {
  match n {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'a'
    11 => 'b'
    12 => 'c'
    13 => 'd'
    14 => 'e'
    _ => 'f'
  }
}

fn append_json_string(builder : StringBuilder, s : String) -> Unit {
  builder.write_char('"')
  for ch in s.iter() {
    match ch {
      '"' => builder.write_string("\\\"")
      '\\' => builder.write_string("\\\\")
      '\b' => builder.write_string("\\b")
      '\f' => builder.write_string("\\f")
      '\n' => builder.write_string("\\n")
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      _ => {
        let code = ch.to_int()
        if code < 0x20 {
          builder.write_string("\\u00")
          builder.write_char(hex_digit((code >> 4) & 0xF))
          builder.write_char(hex_digit(code & 0xF))
        } else {
          builder.write_char(ch)
        }
      }
    }
  }
  builder.write_char('"')
}

fn json_quoted_string(s : String) -> String {
  let builder = StringBuilder()
  append_json_string(builder, s)
  builder.to_string()
}

fn read_n_bytes(input : InputStream, length : Int) -> Result[(Bytes, InputStream), String] {
  let mut cur = input
  let out : Array[Byte] = []
  for _ in 0..<length {
    match input_stream_read_int(cur) {
      Ok((b, next)) => {
        out.push(b.to_byte())
        cur = next
      }
      Err(e) => return Err(e)
    }
  }
  Ok((Bytes::from_array(out), cur))
}

fn encode_length_prefixed_bytes(out : OutputStream, wire : Int, length : Int) -> OutputStream {
  if length < 232 {
    output_stream_write_ints(out, [wire, length])
  } else if length < 65536 {
    output_stream_write_ints(out, [wire, 232, length & 0xFF, (length >> 8) & 0xFF])
  } else {
    output_stream_write_ints(
      out,
      [
        wire,
        233,
        length & 0xFF,
        (length >> 8) & 0xFF,
        (length >> 16) & 0xFF,
        (length >> 24) & 0xFF,
      ],
    )
  }
}

fn decode_number_with_tail(input : InputStream) -> Result[(Int64, InputStream), String] {
  match input_stream_read_int(input) {
    Ok((wire, rest)) => decode_number_body(wire, rest)
    Err(e) => Err(e)
  }
}

fn bytes_to_hex_string(bytes : Bytes) -> String {
  let builder = StringBuilder()
  for byte in bytes.to_array() {
    let n = byte.to_int()
    builder.write_char(hex_digit((n >> 4) & 0xF))
    builder.write_char(hex_digit(n & 0xF))
  }
  builder.to_string()
}

fn output_stream_write_bytes(out : OutputStream, bytes : Bytes) -> OutputStream {
  let mut cur = out
  for byte in bytes.to_array() {
    cur = output_stream_write_byte(cur, byte)
  }
  cur
}

pub fn string_serializer() -> Serializer[String] {
  new_serializer({
    is_default: fn(input : String) { input == "" },
    to_dense_json: fn(input : String, builder : StringBuilder) {
      append_json_string(builder, input)
    },
    to_readable_json: fn(input : String) {
      parse_json(json_quoted_string(input))
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::String(s) => Ok(s)
        Json::Number(n, ..) => if n == 0.0 { Ok("") } else { Err("expected string") }
        _ => Err("expected string")
      }
    },
    encode: fn(input : String, out : OutputStream) {
      let bytes = @utf8.encode(input)
      if bytes.is_empty() {
        output_stream_write_int(out, 242)
      } else {
        let out = encode_length_prefixed_bytes(out, 243, bytes.length())
        output_stream_write_bytes(out, bytes)
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match input_stream_read_int(input) {
        Ok((wire, rest)) =>
          match wire {
            0 => Ok("")
            242 => Ok("")
            243 =>
              match decode_number_with_tail(rest) {
                Ok((length, tail)) =>
                  match read_n_bytes(tail, length.to_int()) {
                    Ok((bytes, _tail)) =>
                      try {
                        Ok(@utf8.decode(bytes[:]))
                      } catch {
                        _ => Err("invalid UTF-8")
                      }
                    Err(e) => Err(e)
                  }
                Err(e) => Err(e)
              }
            _ => Err("expected string")
          }
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::String),
        records: [],
      }
    },
  })
}

pub fn bytes_serializer() -> Serializer[Bytes] {
  new_serializer({
    is_default: fn(input : Bytes) { input.is_empty() },
    to_dense_json: fn(input : Bytes, builder : StringBuilder) {
      append_json_string(builder, @base64.encode(input))
    },
    to_readable_json: fn(input : Bytes) {
      parse_json(json_quoted_string("hex:" + bytes_to_hex_string(input)))
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::String(s) =>
          if s.has_prefix("hex:") {
            let hex = s[4:]
            if hex.length() == 0 {
              Ok(Bytes::default())
            } else if hex.length() % 2 != 0 {
              Err("invalid hex bytes")
            } else {
              let mut cur = 0
              let out : Array[Byte] = []
              while cur < hex.length() {
                let byte_text = hex[cur:cur + 2]
                try {
                  let value = @string.parse_uint(byte_text, base=16)
                  out.push(value.to_byte())
                } catch {
                  _ => return Err("invalid hex bytes")
                }
                cur = cur + 2
              }
              Ok(Bytes::from_array(out))
            }
          } else {
            try {
              Ok(@base64.decode(s))
            } catch {
              _ => Err("invalid base64 bytes")
            }
          }
        Json::Number(n, ..) => if n == 0.0 { Ok(Bytes::default()) } else { Err("expected bytes") }
        _ => Err("expected bytes")
      }
    },
    encode: fn(input : Bytes, out : OutputStream) {
      if input.is_empty() {
        output_stream_write_int(out, 244)
      } else {
        let out = encode_length_prefixed_bytes(out, 245, input.length())
        output_stream_write_bytes(out, input)
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match input_stream_read_int(input) {
        Ok((wire, rest)) =>
          match wire {
            0 => Ok(Bytes::default())
            244 => Ok(Bytes::default())
            245 =>
              match decode_number_with_tail(rest) {
                Ok((length, tail)) =>
                  match read_n_bytes(tail, length.to_int()) {
                    Ok((bytes, _tail)) => Ok(bytes)
                    Err(e) => Err(e)
                  }
                Err(e) => Err(e)
              }
            _ => Err("expected bytes")
          }
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Bytes),
        records: [],
      }
    },
  })
}

fn encode_u16_le(v : Int) -> Array[Int] {
  [v & 0xFF, (v >> 8) & 0xFF]
}

fn encode_u32_le(v : Int) -> Array[Int] {
  [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]
}

fn encode_i64_le(v : Int64) -> Array[Int] {
  encode_u64_le(v.reinterpret_as_uint64())
}

fn encode_u64_le(v : UInt64) -> Array[Int] {
  [
    (v & 0xFFUL).to_int(),
    ((v >> 8) & 0xFFUL).to_int(),
    ((v >> 16) & 0xFFUL).to_int(),
    ((v >> 24) & 0xFFUL).to_int(),
    ((v >> 32) & 0xFFUL).to_int(),
    ((v >> 40) & 0xFFUL).to_int(),
    ((v >> 48) & 0xFFUL).to_int(),
    ((v >> 56) & 0xFFUL).to_int(),
  ]
}

fn encode_i32(v : Int) -> Array[Int] {
  if v < -65536 {
    [237, ..encode_u32_le(v)]
  } else if v < -256 {
    [236, ..encode_u16_le(v)]
  } else if v < 0 {
    [235, v & 0xFF]
  } else if v <= 231 {
    [v]
  } else if v <= 65535 {
    [232, ..encode_u16_le(v)]
  } else {
    [233, ..encode_u32_le(v)]
  }
}

fn read_u16(input : InputStream) -> Result[(Int, InputStream), String] {
  match input_stream_read_int(input) {
    Ok((b0, tail0)) =>
      match input_stream_read_int(tail0) {
        Ok((b1, tail1)) => Ok((b0 | (b1 << 8), tail1))
        Err(e) => Err(e)
      }
    Err(e) => Err(e)
  }
}

fn read_u32(input : InputStream) -> Result[(Int64, InputStream), String] {
  match input_stream_read_int(input) {
    Ok((b0, tail0)) =>
      match input_stream_read_int(tail0) {
        Ok((b1, tail1)) =>
          match input_stream_read_int(tail1) {
            Ok((b2, tail2)) =>
              match input_stream_read_int(tail2) {
                Ok((b3, tail3)) => {
                  let v =
                    Int64::from_int(b0) |
                    (Int64::from_int(b1) << 8) |
                    (Int64::from_int(b2) << 16) |
                    (Int64::from_int(b3) << 24)
                  Ok((v, tail3))
                }
                Err(e) => Err(e)
              }
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    Err(e) => Err(e)
  }
}

fn read_i32(input : InputStream) -> Result[(Int, InputStream), String] {
  match read_u32(input) {
    Ok((u, rest)) => {
      if u >= 2147483648L {
        Ok(((u - 4294967296L).to_int(), rest))
      } else {
        Ok((u.to_int(), rest))
      }
    }
    Err(e) => Err(e)
  }
}

fn read_i64(input : InputStream) -> Result[(Int64, InputStream), String] {
  match input_stream_read_int(input) {
    Ok((b0, tail0)) =>
      match input_stream_read_int(tail0) {
        Ok((b1, tail1)) =>
          match input_stream_read_int(tail1) {
            Ok((b2, tail2)) =>
              match input_stream_read_int(tail2) {
                Ok((b3, tail3)) =>
                  match input_stream_read_int(tail3) {
                    Ok((b4, tail4)) =>
                      match input_stream_read_int(tail4) {
                        Ok((b5, tail5)) =>
                          match input_stream_read_int(tail5) {
                            Ok((b6, tail6)) =>
                              match input_stream_read_int(tail6) {
                                Ok((b7, tail7)) => {
                                  let v =
                                    Int64::from_int(b0) |
                                    (Int64::from_int(b1) << 8) |
                                    (Int64::from_int(b2) << 16) |
                                    (Int64::from_int(b3) << 24) |
                                    (Int64::from_int(b4) << 32) |
                                    (Int64::from_int(b5) << 40) |
                                    (Int64::from_int(b6) << 48) |
                                    (Int64::from_int(b7) << 56)
                                  Ok((v, tail7))
                                }
                                Err(e) => Err(e)
                              }
                            Err(e) => Err(e)
                          }
                        Err(e) => Err(e)
                      }
                    Err(e) => Err(e)
                  }
                Err(e) => Err(e)
              }
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    Err(e) => Err(e)
  }
}

fn read_u64(input : InputStream) -> Result[(UInt64, InputStream), String] {
  match input_stream_read_int(input) {
    Ok((b0, tail0)) =>
      match input_stream_read_int(tail0) {
        Ok((b1, tail1)) =>
          match input_stream_read_int(tail1) {
            Ok((b2, tail2)) =>
              match input_stream_read_int(tail2) {
                Ok((b3, tail3)) =>
                  match input_stream_read_int(tail3) {
                    Ok((b4, tail4)) =>
                      match input_stream_read_int(tail4) {
                        Ok((b5, tail5)) =>
                          match input_stream_read_int(tail5) {
                            Ok((b6, tail6)) =>
                              match input_stream_read_int(tail6) {
                                Ok((b7, tail7)) => {
                                  let v =
                                    b0.to_uint64() |
                                    (b1.to_uint64() << 8) |
                                    (b2.to_uint64() << 16) |
                                    (b3.to_uint64() << 24) |
                                    (b4.to_uint64() << 32) |
                                    (b5.to_uint64() << 40) |
                                    (b6.to_uint64() << 48) |
                                    (b7.to_uint64() << 56)
                                  Ok((v, tail7))
                                }
                                Err(e) => Err(e)
                              }
                            Err(e) => Err(e)
                          }
                        Err(e) => Err(e)
                      }
                    Err(e) => Err(e)
                  }
                Err(e) => Err(e)
              }
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    Err(e) => Err(e)
  }
}

fn decode_number_body(wire : Int, input : InputStream) -> Result[(Int64, InputStream), String] {
  match wire {
    0..=231 => Ok((Int64::from_int(wire), input))
    232 =>
      match read_u16(input) {
        Ok((v, rest)) => Ok((Int64::from_int(v), rest))
        Err(e) => Err(e)
      }
    233 =>
      match read_u32(input) {
        Ok((v, rest)) => Ok((v, rest))
        Err(e) => Err(e)
      }
    234 =>
      match read_u64(input) {
        Ok((v, rest)) => Ok((v.reinterpret_as_int64(), rest))
        Err(e) => Err(e)
      }
    235 =>
      match input_stream_read_int(input) {
        Ok((b, rest)) => Ok((Int64::from_int(b - 256), rest))
        Err(e) => Err(e)
      }
    236 =>
      match read_u16(input) {
        Ok((v, rest)) => Ok((Int64::from_int(v - 65536), rest))
        Err(e) => Err(e)
      }
    237 =>
      match read_i32(input) {
        Ok((v, rest)) => Ok((Int64::from_int(v), rest))
        Err(e) => Err(e)
      }
    238 => read_i64(input)
    239 => read_i64(input)
    240 =>
      match input_stream_read_int(input) {
        Ok((b0, tail0)) =>
          match input_stream_read_int(tail0) {
            Ok((b1, tail1)) =>
              match input_stream_read_int(tail1) {
                Ok((b2, tail2)) =>
                  match input_stream_read_int(tail2) {
                    Ok((b3, tail3)) => {
                      let bits =
                        b0.reinterpret_as_uint() |
                        (b1.reinterpret_as_uint() << 8) |
                        (b2.reinterpret_as_uint() << 16) |
                        (b3.reinterpret_as_uint() << 24)
                      let f = Float::reinterpret_from_uint(bits)
                      Ok((Int64::from_int(f.trunc().to_int()), tail3))
                    }
                    Err(e) => Err(e)
                  }
                Err(e) => Err(e)
              }
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    241 =>
      match read_i64(input) {
        Ok((bits, rest)) => {
          let d = bits.reinterpret_as_double()
          Ok((d.trunc().to_int64(), rest))
        }
        Err(e) => Err(e)
      }
    _ => Ok((0L, input))
  }
}

fn decode_number(input : InputStream) -> Result[Int64, String] {
  match input_stream_read_int(input) {
    Ok((wire, rest)) =>
      match decode_number_body(wire, rest) {
        Ok((v, _tail)) => Ok(v)
        Err(e) => Err(e)
      }
    Err(e) => Err(e)
  }
}

fn parse_double_or_zero(s : String) -> Double {
  try {
    @string.parse_double(s)
  } catch {
    _ => 0.0
  }
}

fn parse_int64_or_zero(s : String) -> Int64 {
  try {
    @string.parse_int64(s)
  } catch {
    _ => 0L
  }
}

fn parse_uint64_or_zero(s : String) -> UInt64 {
  try {
    @string.parse_uint64(s)
  } catch {
    _ => 0UL
  }
}

fn decode_number_as_double_body(
  wire : Int,
  input : InputStream
) -> Result[(Double, InputStream), String] {
  match wire {
    0..=231 => Ok((wire.to_double(), input))
    232 =>
      match read_u16(input) {
        Ok((v, rest)) => Ok((v.to_double(), rest))
        Err(e) => Err(e)
      }
    233 =>
      match read_u32(input) {
        Ok((v, rest)) => Ok((v.to_double(), rest))
        Err(e) => Err(e)
      }
    234 =>
      match read_u64(input) {
        Ok((v, rest)) => Ok((v.to_double(), rest))
        Err(e) => Err(e)
      }
    235 =>
      match input_stream_read_int(input) {
        Ok((b, rest)) => Ok(((b - 256).to_double(), rest))
        Err(e) => Err(e)
      }
    236 =>
      match read_u16(input) {
        Ok((v, rest)) => Ok(((v - 65536).to_double(), rest))
        Err(e) => Err(e)
      }
    237 =>
      match read_i32(input) {
        Ok((v, rest)) => Ok((v.to_double(), rest))
        Err(e) => Err(e)
      }
    238 =>
      match read_i64(input) {
        Ok((v, rest)) => Ok((v.to_double(), rest))
        Err(e) => Err(e)
      }
    239 =>
      match read_i64(input) {
        Ok((v, rest)) => Ok((v.to_double(), rest))
        Err(e) => Err(e)
      }
    240 =>
      match input_stream_read_int(input) {
        Ok((b0, tail0)) =>
          match input_stream_read_int(tail0) {
            Ok((b1, tail1)) =>
              match input_stream_read_int(tail1) {
                Ok((b2, tail2)) =>
                  match input_stream_read_int(tail2) {
                    Ok((b3, tail3)) => {
                      let bits =
                        b0.reinterpret_as_uint() |
                        (b1.reinterpret_as_uint() << 8) |
                        (b2.reinterpret_as_uint() << 16) |
                        (b3.reinterpret_as_uint() << 24)
                      let f = Float::reinterpret_from_uint(bits)
                      Ok((f.to_double(), tail3))
                    }
                    Err(e) => Err(e)
                  }
                Err(e) => Err(e)
              }
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    241 =>
      match read_i64(input) {
        Ok((bits, rest)) => Ok((bits.reinterpret_as_double(), rest))
        Err(e) => Err(e)
      }
    _ => Ok((0.0, input))
  }
}

fn decode_number_as_double(input : InputStream) -> Result[Double, String] {
  match input_stream_read_int(input) {
    Ok((wire, rest)) =>
      match decode_number_as_double_body(wire, rest) {
        Ok((v, _tail)) => Ok(v)
        Err(e) => Err(e)
      }
    Err(e) => Err(e)
  }
}

pub fn int32_serializer() -> Serializer[Int] {
  new_serializer({
    is_default: fn(input : Int) { input == 0 },
    to_dense_json: fn(input : Int, builder : StringBuilder) {
      builder.write_string(input.to_string())
    },
    to_readable_json: fn(input : Int) { parse_json(input.to_string()) },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::Number(n, ..) => Ok(n.to_int())
        Json::String(s) => Ok(parse_double_or_zero(s).to_int())
        _ => Ok(0)
      }
    },
    encode: fn(input : Int, out : OutputStream) {
      output_stream_write_ints(out, encode_i32(input))
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match decode_number(input) {
        Ok(v) => Ok(v.to_int())
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Int32),
        records: [],
      }
    },
  })
}

pub fn int64_serializer() -> Serializer[Int64] {
  new_serializer({
    is_default: fn(input : Int64) { input == 0L },
    to_dense_json: fn(input : Int64, builder : StringBuilder) {
      if input >= -max_safe_int64_json && input <= max_safe_int64_json {
        builder.write_string(input.to_string())
      } else {
        builder.write_string("\"" + input.to_string() + "\"")
      }
    },
    to_readable_json: fn(input : Int64) {
      if input >= -max_safe_int64_json && input <= max_safe_int64_json {
        parse_json(input.to_string())
      } else {
        parse_json("\"" + input.to_string() + "\"")
      }
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::Number(n, ..) => Ok(n.round().to_int64())
        Json::String(s) => Ok(parse_int64_or_zero(s))
        _ => Ok(0L)
      }
    },
    encode: fn(input : Int64, out : OutputStream) {
      if input >= Int64::from_int(-2147483648) && input <= Int64::from_int(2147483647) {
        output_stream_write_ints(out, encode_i32(input.to_int()))
      } else {
        output_stream_write_ints(out, [238, ..encode_i64_le(input)])
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      decode_number(input)
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Int64),
        records: [],
      }
    },
  })
}

pub fn hash64_serializer() -> Serializer[UInt64] {
  new_serializer({
    is_default: fn(input : UInt64) { input == 0UL },
    to_dense_json: fn(input : UInt64, builder : StringBuilder) {
      if input <= max_safe_hash64_json {
        builder.write_string(input.to_string())
      } else {
        builder.write_string("\"" + input.to_string() + "\"")
      }
    },
    to_readable_json: fn(input : UInt64) {
      if input <= max_safe_hash64_json {
        parse_json(input.to_string())
      } else {
        parse_json("\"" + input.to_string() + "\"")
      }
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::Number(n, ..) =>
          if n < 0.0 {
            Ok(0UL)
          } else {
            Ok(n.round().to_uint64())
          }
        Json::String(s) => Ok(parse_uint64_or_zero(s))
        _ => Ok(0UL)
      }
    },
    encode: fn(input : UInt64, out : OutputStream) {
      if input <= 231UL {
        output_stream_write_ints(out, [input.to_int()])
      } else if input <= 65535UL {
        output_stream_write_ints(out, [232, ..encode_u16_le(input.to_int())])
      } else if input <= 4294967295UL {
        output_stream_write_ints(out, [233, ..encode_u32_le(input.to_int())])
      } else {
        output_stream_write_ints(out, [234, ..encode_u64_le(input)])
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match decode_number(input) {
        Ok(v) => Ok(v.reinterpret_as_uint64())
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Hash64),
        records: [],
      }
    },
  })
}

pub fn float32_serializer() -> Serializer[Float] {
  new_serializer({
    is_default: fn(input : Float) { input == 0.0 },
    to_dense_json: fn(input : Float, builder : StringBuilder) {
      builder.write_string(input.to_string())
    },
    to_readable_json: fn(input : Float) { parse_json(input.to_string()) },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::Number(n, ..) => Ok(Float::from_double(n))
        Json::String(s) => Ok(Float::from_double(parse_double_or_zero(s)))
        _ => Ok(Float::from_double(0.0))
      }
    },
    encode: fn(input : Float, out : OutputStream) {
      if input == 0.0 {
        output_stream_write_int(out, 0)
      } else {
        let bits = input.reinterpret_as_int()
        output_stream_write_ints(
          out,
          [
            240,
            bits & 0xFF,
            (bits >> 8) & 0xFF,
            (bits >> 16) & 0xFF,
            (bits >> 24) & 0xFF,
          ],
        )
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match decode_number_as_double(input) {
        Ok(v) => Ok(Float::from_double(v))
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Float32),
        records: [],
      }
    },
  })
}

pub fn float64_serializer() -> Serializer[Double] {
  new_serializer({
    is_default: fn(input : Double) { input == 0.0 },
    to_dense_json: fn(input : Double, builder : StringBuilder) {
      builder.write_string(input.to_string())
    },
    to_readable_json: fn(input : Double) { parse_json(input.to_string()) },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      match json {
        Json::Number(n, ..) => Ok(n)
        Json::String(s) => Ok(parse_double_or_zero(s))
        _ => Ok(0.0)
      }
    },
    encode: fn(input : Double, out : OutputStream) {
      if input == 0.0 {
        output_stream_write_int(out, 0)
      } else {
        output_stream_write_ints(out, [241, ..encode_i64_le(input.reinterpret_as_int64())])
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      decode_number_as_double(input)
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Float64),
        records: [],
      }
    },
  })
}

fn int64_div_euclid(a : Int64, b : Int64) -> Int64 {
  let q = a / b
  let r = a % b
  if r < 0L {
    if b > 0L {
      q - 1L
    } else {
      q + 1L
    }
  } else {
    q
  }
}

fn int64_rem_euclid(a : Int64, b : Int64) -> Int64 {
  a - int64_div_euclid(a, b) * b
}

fn zero_pad(n : Int, width : Int) -> String {
  let s = n.to_string()
  if s.length() >= width {
    s
  } else {
    let mut out = ""
    for _ in 0..<(width - s.length()) {
      out += "0"
    }
    out + s
  }
}

fn millis_to_iso8601(ms0 : Int64) -> String {
  let ms = clamp_timestamp_millis(ms0)
  let millis_part = int64_rem_euclid(ms, 1000L).to_int()
  let secs = int64_div_euclid(ms, 1000L)
  let time_of_day = int64_rem_euclid(secs, 86400L)
  let h = (time_of_day / 3600L).to_int()
  let mi = ((time_of_day % 3600L) / 60L).to_int()
  let s = (time_of_day % 60L).to_int()

  let days = int64_div_euclid(secs, 86400L)
  let z = days + 719468L
  let era = int64_div_euclid(z, 146097L)
  let doe = z - era * 146097L
  let yoe =
    int64_div_euclid(
      doe - int64_div_euclid(doe, 1460L) + int64_div_euclid(doe, 36524L) -
      int64_div_euclid(doe, 146096L),
      365L,
    )
  let y = yoe + era * 400L
  let doy =
    doe - (365L * yoe + int64_div_euclid(yoe, 4L) - int64_div_euclid(yoe, 100L))
  let mp = int64_div_euclid(5L * doy + 2L, 153L)
  let d = (doy - int64_div_euclid(153L * mp + 2L, 5L) + 1L).to_int()
  let m = if mp < 10L { (mp + 3L).to_int() } else { (mp - 9L).to_int() }
  let y_final = if m <= 2 { y + 1L } else { y }

  let y_str =
    if y_final >= 0L {
      zero_pad(y_final.to_int(), 4)
    } else {
      y_final.to_string()
    }

  y_str +
  "-" +
  zero_pad(m, 2) +
  "-" +
  zero_pad(d, 2) +
  "T" +
  zero_pad(h, 2) +
  ":" +
  zero_pad(mi, 2) +
  ":" +
  zero_pad(s, 2) +
  "." +
  zero_pad(millis_part, 3) +
  "Z"
}

fn timestamp_json_to_millis(json : Json) -> Int64 {
  match json {
    Json::Number(n, ..) => n.round().to_int64()
    Json::String(s) => parse_double_or_zero(s).round().to_int64()
    Json::Object(obj) =>
      match obj.get("unix_millis") {
        Some(field) => timestamp_json_to_millis(field)
        None => 0L
      }
    _ => 0L
  }
}

pub fn timestamp_serializer() -> Serializer[Timestamp] {
  new_serializer({
    is_default: fn(input : Timestamp) { input.to_unix_millis() == 0L },
    to_dense_json: fn(input : Timestamp, builder : StringBuilder) {
      let ms = clamp_timestamp_millis(input.to_unix_millis())
      builder.write_string(ms.to_string())
    },
    to_readable_json: fn(input : Timestamp) {
      let ms = clamp_timestamp_millis(input.to_unix_millis())
      parse_json(
        "{\n  \"unix_millis\": " +
        ms.to_string() +
        ",\n  \"formatted\": \"" +
        millis_to_iso8601(ms) +
        "\"\n}",
      )
    },
    from_json: fn(json : Json, _policy : UnrecognizedValues) {
      Ok(timestamp_from_unix_millis(timestamp_json_to_millis(json)))
    },
    encode: fn(input : Timestamp, out : OutputStream) {
      let ms = clamp_timestamp_millis(input.to_unix_millis())
      if ms == 0L {
        output_stream_write_int(out, 0)
      } else {
        output_stream_write_ints(out, [239, ..encode_i64_le(ms)])
      }
    },
    decode: fn(input : InputStream, _policy : UnrecognizedValues) {
      match decode_number(input) {
        Ok(ms) => Ok(timestamp_from_unix_millis(ms))
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Primitive(PrimitiveType::Timestamp),
        records: [],
      }
    },
  })
}

fn expect_ok_bool(r : Result[Bool, String]) -> Bool {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

fn expect_ok_int(r : Result[Int, String]) -> Int {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

fn expect_ok_int64(r : Result[Int64, String]) -> Int64 {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

fn expect_ok_uint64(r : Result[UInt64, String]) -> UInt64 {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

fn expect_ok_float(r : Result[Float, String]) -> Float {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

fn expect_ok_double(r : Result[Double, String]) -> Double {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

fn expect_ok_timestamp(r : Result[Timestamp, String]) -> Timestamp {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

fn[T : Eq] assert_eq(lhs : T, rhs : T) -> Unit {
  if lhs != rhs {
    panic()
  }
}

test "to_json_dense_true" {
  assert_eq(bool_serializer().to_dense_json(true), "1")
}

test "to_json_dense_false" {
  assert_eq(bool_serializer().to_dense_json(false), "0")
}

test "to_json_readable_true" {
  assert_eq(bool_serializer().to_readable_json(true), parse_json("true"))
}

test "to_json_readable_false" {
  assert_eq(bool_serializer().to_readable_json(false), parse_json("false"))
}

test "from_json_bool_literal" {
  let s = bool_serializer()
  assert_eq(expect_ok_bool(s.from_json("true", UnrecognizedValues::Drop)), true)
  assert_eq(expect_ok_bool(s.from_json("false", UnrecognizedValues::Drop)), false)
}

test "from_json_number_1_and_0" {
  let s = bool_serializer()
  assert_eq(expect_ok_bool(s.from_json("1", UnrecognizedValues::Drop)), true)
  assert_eq(expect_ok_bool(s.from_json("0", UnrecognizedValues::Drop)), false)
  assert_eq(expect_ok_bool(s.from_json("1", UnrecognizedValues::Keep)), true)
}

test "from_json_number_nonzero" {
  assert_eq(
    expect_ok_bool(bool_serializer().from_json("42", UnrecognizedValues::Drop)),
    true,
  )
}

test "from_json_float_zero" {
  assert_eq(
    expect_ok_bool(bool_serializer().from_json("0.0", UnrecognizedValues::Drop)),
    false,
  )
}

test "from_json_string_zero_is_false" {
  assert_eq(
    expect_ok_bool(bool_serializer().from_json("\"0\"", UnrecognizedValues::Drop)),
    false,
  )
}

test "from_json_string_nonzero_is_true" {
  assert_eq(
    expect_ok_bool(bool_serializer().from_json("\"1\"", UnrecognizedValues::Drop)),
    true,
  )
  assert_eq(
    expect_ok_bool(bool_serializer().from_json("\"true\"", UnrecognizedValues::Drop)),
    true,
  )
}

test "from_json_null_is_false" {
  assert_eq(
    expect_ok_bool(bool_serializer().from_json("null", UnrecognizedValues::Drop)),
    false,
  )
}

test "binary_round_trip_true" {
  let s = bool_serializer()
  let bytes = s.to_bytes(true)
  assert_eq(expect_ok_bool(s.from_bytes(bytes, UnrecognizedValues::Drop)), true)
}

test "binary_round_trip_false" {
  let s = bool_serializer()
  let bytes = s.to_bytes(false)
  assert_eq(expect_ok_bool(s.from_bytes(bytes, UnrecognizedValues::Drop)), false)
}

test "binary_encoding_true_is_skir_then_1" {
  assert_eq(bool_serializer().to_bytes(true), [115, 107, 105, 114, 1])
}

test "binary_encoding_false_is_skir_then_0" {
  assert_eq(bool_serializer().to_bytes(false), [115, 107, 105, 114, 0])
}

test "type_descriptor_is_bool" {
  let td = bool_serializer().type_descriptor()
  assert_eq(
    td.as_json(),
    {
      "type": {
        "kind": "primitive",
        "value": "bool",
      },
      "records": [],
    },
  )
}

test "int32_to_json_positive" {
  assert_eq(int32_serializer().to_dense_json(42), "42")
}

test "int32_from_json_float_truncates" {
  assert_eq(expect_ok_int(int32_serializer().from_json("3.9", UnrecognizedValues::Drop)), 3)
  assert_eq(expect_ok_int(int32_serializer().from_json("-1.5", UnrecognizedValues::Drop)), -1)
}

test "int32_binary_round_trip" {
  let s = int32_serializer()
  for v in [0, 1, 42, 231, 232, 300, 65535, 65536, -1, -255, -256, -65536, -100000] {
    assert_eq(expect_ok_int(s.from_bytes(s.to_bytes(v), UnrecognizedValues::Drop)), v)
  }
}

test "int64_to_json_large_value_is_quoted" {
  assert_eq(
    int64_serializer().to_dense_json(9007199254740992L),
    "\"9007199254740992\"",
  )
}

test "int64_from_json_quoted_large" {
  assert_eq(
    expect_ok_int64(int64_serializer().from_json("\"9007199254740992\"", UnrecognizedValues::Drop)),
    9007199254740992L,
  )
}

test "int64_binary_round_trip" {
  let s = int64_serializer()
  for v in [
    0L,
    1L,
    231L,
    232L,
    65536L,
    2147483647L,
    2147483648L,
    -1L,
    -2147483648L,
    -2147483649L,
  ] {
    assert_eq(expect_ok_int64(s.from_bytes(s.to_bytes(v), UnrecognizedValues::Drop)), v)
  }
}

test "hash64_to_json_large_value_is_quoted" {
  assert_eq(
    hash64_serializer().to_dense_json(9007199254740992UL),
    "\"9007199254740992\"",
  )
}

test "hash64_from_json_negative_number_is_zero" {
  assert_eq(
    expect_ok_uint64(hash64_serializer().from_json("-1.0", UnrecognizedValues::Drop)),
    0UL,
  )
}

test "hash64_binary_round_trip" {
  let s = hash64_serializer()
  for v in [0UL, 1UL, 231UL, 232UL, 65535UL, 65536UL, 4294967295UL, 4294967296UL] {
    assert_eq(expect_ok_uint64(s.from_bytes(s.to_bytes(v), UnrecognizedValues::Drop)), v)
  }
}

test "float32_to_json" {
  assert_eq(float32_serializer().to_dense_json(Float::from_double(1.5)), "1.5")
}

test "float32_from_json_string" {
  assert_eq(
    expect_ok_float(float32_serializer().from_json("\"3.25\"", UnrecognizedValues::Drop)),
    Float::from_double(3.25),
  )
}

test "float32_binary_round_trip" {
  let s = float32_serializer()
  for v in [Float::from_double(0.0), Float::from_double(1.5), Float::from_double(-2.25)] {
    assert_eq(expect_ok_float(s.from_bytes(s.to_bytes(v), UnrecognizedValues::Drop)), v)
  }
}

test "float32_binary_encoding_1_5" {
  assert_eq(
    float32_serializer().to_bytes(Float::from_double(1.5)),
    [115, 107, 105, 114, 240, 0, 0, 192, 63],
  )
}

test "float64_to_json" {
  assert_eq(float64_serializer().to_dense_json(1.5), "1.5")
}

test "float64_from_json_string" {
  assert_eq(
    expect_ok_double(float64_serializer().from_json("\"3.25\"", UnrecognizedValues::Drop)),
    3.25,
  )
}

test "float64_binary_round_trip" {
  let s = float64_serializer()
  for v in [0.0, 1.5, -2.25, 123456789.125] {
    assert_eq(expect_ok_double(s.from_bytes(s.to_bytes(v), UnrecognizedValues::Drop)), v)
  }
}

test "float64_binary_encoding_1_5" {
  assert_eq(
    float64_serializer().to_bytes(1.5),
    [115, 107, 105, 114, 241, 0, 0, 0, 0, 0, 0, 248, 63],
  )
}

test "timestamp_to_json_dense_epoch" {
  let epoch = timestamp_from_unix_millis(0L)
  assert_eq(timestamp_serializer().to_dense_json(epoch), "0")
}

test "timestamp_to_json_readable" {
  let ts = timestamp_from_unix_millis(1234567890000L)
  assert_eq(
    timestamp_serializer().to_readable_json(ts),
    parse_json(
      "{\n  \"unix_millis\": 1234567890000,\n  \"formatted\": \"2009-02-13T23:31:30.000Z\"\n}",
    ),
  )
}

test "timestamp_from_json_object_readable" {
  let json = "{\"unix_millis\":1234567890000,\"formatted\":\"ignored\"}"
  let parsed = expect_ok_timestamp(timestamp_serializer().from_json(json, UnrecognizedValues::Drop))
  assert_eq(parsed.to_unix_millis(), 1234567890000L)
}

test "timestamp_binary_round_trip" {
  let s = timestamp_serializer()
  for ms in [0L, 1L, 1234567890000L, -1000L] {
    let ts = timestamp_from_unix_millis(ms)
    let decoded =
      expect_ok_timestamp(s.from_bytes(s.to_bytes(ts), UnrecognizedValues::Drop)).to_unix_millis()
    assert_eq(decoded, clamp_timestamp_millis(ms))
  }
}
