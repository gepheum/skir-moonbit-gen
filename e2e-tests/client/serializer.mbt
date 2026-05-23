pub enum JsonFlavor {
  Dense
  Readable
}

pub enum UnrecognizedValues {
  Keep
  Drop
}

struct TypeAdapter[T] {
  is_default : (T) -> Bool
  to_json : (T, JsonFlavor) -> String
  from_json : (Json, Bool) -> Result[T, String]
  encode : (T) -> Array[Int]
  decode : (Array[Int], Bool) -> Result[T, String]
  type_descriptor : () -> TypeDescriptor
}

pub struct Serializer[T] {
  adapter : TypeAdapter[T]
}

fn[T] new_serializer(adapter : TypeAdapter[T]) -> Serializer[T] {
  let s : Serializer[T] = { adapter, }
  s
}

pub fn[T] Serializer::to_json(
  self : Serializer[T],
  input : T,
  flavor : JsonFlavor
) -> String {
  (self.adapter.to_json)(input, flavor)
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
  let keep_unrecognized =
    match policy {
      UnrecognizedValues::Keep => true
      UnrecognizedValues::Drop => false
    }
  (self.adapter.from_json)(root, keep_unrecognized)
}

pub fn[T] Serializer::to_bytes(self : Serializer[T], input : T) -> Array[Int] {
  let out : Array[Int] = [115, 107, 105, 114]
  let payload = (self.adapter.encode)(input)
  for b in payload {
    out.push(b)
  }
  out
}

pub fn[T] Serializer::from_bytes(
  self : Serializer[T],
  bytes : Array[Int],
  policy : UnrecognizedValues
) -> Result[T, String] {
  let keep_unrecognized =
    match policy {
      UnrecognizedValues::Keep => true
      UnrecognizedValues::Drop => false
    }
  match bytes {
      [115, 107, 105, 114, ..payload] =>
        (self.adapter.decode)(payload.iter().to_array(), keep_unrecognized)
    _ => Err("invalid binary payload")
  }
}

  pub fn[T] Serializer::type_descriptor(self : Serializer[T]) -> TypeDescriptor {
    (self.adapter.type_descriptor)()
}
