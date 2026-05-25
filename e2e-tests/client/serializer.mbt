pub enum UnrecognizedValues {
  Keep
  Drop
}

pub fn unrecognized_values_keep() -> UnrecognizedValues {
  UnrecognizedValues::Keep
}

pub fn unrecognized_values_drop() -> UnrecognizedValues {
  UnrecognizedValues::Drop
}

struct TypeAdapter[T] {
  is_default : (T) -> Bool
  to_dense_json : (T, StringBuilder) -> Unit
  to_readable_json : (T) -> Json
  from_json : (Json, UnrecognizedValues) -> Result[T, String]
  encode : (T, OutputStream) -> OutputStream
  decode : (InputStream, UnrecognizedValues) -> Result[(T, InputStream), String]
  type_descriptor : () -> TypeDescriptor
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
  let mut out = OutputStream::new()
  out = out.write_int(115)
  out = out.write_int(107)
  out = out.write_int(105)
  out = out.write_int(114)
  out = (self.adapter.encode)(input, out)
  out.to_int_array()
}

pub fn[T] Serializer::from_bytes(
  self : Serializer[T],
  bytes : Array[Int],
  policy : UnrecognizedValues
) -> Result[T, String] {
  match bytes {
      [115, 107, 105, 114, ..payload] =>
        match (self.adapter.decode)(
          InputStream::from_int_array(payload.iter().to_array()),
          policy,
        ) {
          Ok((value, _tail)) => Ok(value)
          Err(e) => Err(e)
        }
    _ => Err("invalid binary payload")
  }
}

  pub fn[T] Serializer::type_descriptor(self : Serializer[T]) -> TypeDescriptor {
    (self.adapter.type_descriptor)()
}
