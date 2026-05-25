pub struct Serializer[T] {
  priv adapter : TypeAdapter[T]
}

pub fn[T] Serializer::to_dense_json_code(self : Serializer[T], input : T) -> String {
  let builder = StringBuilder::new()
  (self.adapter.to_dense_json)(input, builder)
  builder.to_string()
}

pub fn[T] Serializer::to_readable_json(self : Serializer[T], input : T) -> Json {
  (self.adapter.to_readable_json)(input)
}

pub fn[T] Serializer::from_json(
  self : Serializer[T],
  json : Json,
  unrecognized_values~ : UnrecognizedValues = UnrecognizedValues::Drop
) -> Result[T, String] {
  (self.adapter.from_json)(json, unrecognized_values)
}

pub fn[T] Serializer::from_json_code(
  self : Serializer[T],
  code : String,
  unrecognized_values~ : UnrecognizedValues = UnrecognizedValues::Drop
) -> Result[T, String] {
  let root =
    try {
      @json.parse(code)
    } catch {
      e => return Err("invalid JSON: " + e.to_string())
    }
  self.from_json(root, unrecognized_values=unrecognized_values)
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
  unrecognized_values~ : UnrecognizedValues = UnrecognizedValues::Drop
) -> Result[T, String] {
  match bytes {
      [115, 107, 105, 114, ..payload] =>
        match (self.adapter.decode)(
          InputStream::from_int_array(payload.iter().to_array()),
          unrecognized_values,
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

pub(all) enum UnrecognizedValues {
  Keep
  Drop
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

fn[T] new_serializer(adapter : TypeAdapter[T]) -> Serializer[T] {
  let s : Serializer[T] = { adapter, }
  s
}
