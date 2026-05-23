pub enum UnrecognizedValues {
  Keep
  Drop
}

struct TypeAdapter[T] {
  is_default : (T) -> Bool
  to_dense_json : (T, StringBuilder) -> Unit
  to_readable_json : (T) -> Json
  from_json : (Json, UnrecognizedValues) -> Result[T, String]
  encode : (T, OutputStream) -> OutputStream
  decode : (InputStream, UnrecognizedValues) -> Result[T, String]
  type_descriptor : () -> TypeDescriptor
}

pub struct OutputStream {
  bytes : Array[Byte]
  offset : Int
}

pub fn output_stream_new() -> OutputStream {
  { bytes: [], offset: 0 }
}

pub fn output_stream_write_byte(out : OutputStream, b : Byte) -> OutputStream {
  out.bytes.push(b)
  { bytes: out.bytes, offset: out.offset + 1 }
}

pub fn output_stream_write_int(out : OutputStream, b : Int) -> OutputStream {
  output_stream_write_byte(out, b.to_byte())
}

pub fn output_stream_write_ints(out : OutputStream, bytes : Array[Int]) -> OutputStream {
  let mut cur = out
  for b in bytes {
    cur = output_stream_write_int(cur, b)
  }
  cur
}

pub fn output_stream_to_int_array(out : OutputStream) -> Array[Int] {
  let bytes : Array[Int] = []
  for b in out.bytes {
    bytes.push(b.to_int())
  }
  bytes
}

pub struct InputStream {
  bytes : Array[Byte]
  offset : Int
}

pub fn input_stream_from_int_array(bytes : Array[Int]) -> InputStream {
  let out : Array[Byte] = []
  for b in bytes {
    out.push(b.to_byte())
  }
  { bytes: out, offset: 0 }
}

pub fn input_stream_read_int(input : InputStream) -> Result[(Int, InputStream), String] {
  match input.bytes.get(input.offset) {
    Some(b) => Ok((b.to_int(), { bytes: input.bytes, offset: input.offset + 1 }))
    None => Err("unexpected end of input")
  }
}

pub fn input_stream_remaining_int_array(input : InputStream) -> Array[Int] {
  let out : Array[Int] = []
  let mut i = input.offset
  while i < input.bytes.length() {
    out.push(input.bytes[i].to_int())
    i = i + 1
  }
  out
}

pub struct Serializer[T] {
  adapter : TypeAdapter[T]
}

fn[T] new_serializer(adapter : TypeAdapter[T]) -> Serializer[T] {
  let s : Serializer[T] = { adapter, }
  s
}

pub fn[T] Serializer::to_dense_json(self : Serializer[T], input : T) -> String {
  let builder = StringBuilder::new()
  (self.adapter.to_dense_json)(input, builder)
  builder.to_string()
}

pub fn[T] Serializer::to_readable_json(self : Serializer[T], input : T) -> Json {
  (self.adapter.to_readable_json)(input)
}

pub fn[T] Serializer::is_default(self : Serializer[T], input : T) -> Bool {
  (self.adapter.is_default)(input)
}

pub fn[T] Serializer::from_json(
  self : Serializer[T],
  code : String,
  policy : UnrecognizedValues
) -> Result[T, String] {
  let root =
    try {
      @json.parse(code)
    } catch {
      _ => return Err("invalid JSON")
    }
  (self.adapter.from_json)(root, policy)
}

pub fn[T] Serializer::to_bytes(self : Serializer[T], input : T) -> Array[Int] {
  let mut out = output_stream_new()
  out = output_stream_write_int(out, 115)
  out = output_stream_write_int(out, 107)
  out = output_stream_write_int(out, 105)
  out = output_stream_write_int(out, 114)
  out = (self.adapter.encode)(input, out)
  output_stream_to_int_array(out)
}

pub fn[T] Serializer::from_bytes(
  self : Serializer[T],
  bytes : Array[Int],
  policy : UnrecognizedValues
) -> Result[T, String] {
  match bytes {
      [115, 107, 105, 114, ..payload] =>
        (self.adapter.decode)(
          input_stream_from_int_array(payload.iter().to_array()),
          policy,
        )
    _ => Err("invalid binary payload")
  }
}

  pub fn[T] Serializer::type_descriptor(self : Serializer[T]) -> TypeDescriptor {
    (self.adapter.type_descriptor)()
}
