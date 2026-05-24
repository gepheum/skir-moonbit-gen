pub enum UnrecognizedFormat {
  DenseJson
  Bytes
} derive(Eq, Debug)

pub struct UnrecognizedFields[T] {
  format : UnrecognizedFormat
  array_len : Int
  values : Bytes
  unused : T?
}

pub fn[T] unrecognized_fields_from_json(
  array_len : Int,
  json_bytes : Bytes
) -> UnrecognizedFields[T] {
  {
    format: UnrecognizedFormat::DenseJson,
    array_len,
    values: json_bytes,
    unused: None,
  }
}

pub fn[T] unrecognized_fields_from_bytes(
  array_len : Int,
  raw_bytes : Bytes
) -> UnrecognizedFields[T] {
  {
    format: UnrecognizedFormat::Bytes,
    array_len,
    values: raw_bytes,
    unused: None,
  }
}

pub struct UnrecognizedVariant[T] {
  format : UnrecognizedFormat
  number : Int
  value : Bytes
  unused : T?
}

pub fn[T] unrecognized_variant_from_bytes(
  number : Int,
  raw_bytes : Bytes
) -> UnrecognizedVariant[T] {
  {
    format: UnrecognizedFormat::Bytes,
    number,
    value: raw_bytes,
    unused: None,
  }
}

pub fn[T] unrecognized_variant_from_json(
  number : Int,
  json_bytes : Bytes
) -> UnrecognizedVariant[T] {
  {
    format: UnrecognizedFormat::DenseJson,
    number,
    value: json_bytes,
    unused: None,
  }
}

pub impl[T] Eq for UnrecognizedFields[T] with equal(self, other) {
  self.format == other.format &&
  self.array_len == other.array_len &&
  self.values == other.values
}

pub impl[T] Debug for UnrecognizedFields[T] with to_repr(self) {
  Debug::to_repr(self.format)
}

pub impl[T] Eq for UnrecognizedVariant[T] with equal(self, other) {
  self.format == other.format &&
  self.number == other.number &&
  self.value == other.value
}

pub impl[T] Debug for UnrecognizedVariant[T] with to_repr(self) {
  Debug::to_repr(self.format)
}
