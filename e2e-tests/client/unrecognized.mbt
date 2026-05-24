pub enum UnrecognizedFormat {
  DenseJson
  Bytes
} derive(Eq, Debug)

pub struct UnrecognizedFields {
  format : UnrecognizedFormat
  array_len : Int
  values : Bytes
}

pub fn unrecognized_fields_from_json(
  array_len : Int,
  json_bytes : Bytes
) -> UnrecognizedFields {
  {
    format: UnrecognizedFormat::DenseJson,
    array_len,
    values: json_bytes,
  }
}

pub fn unrecognized_fields_from_bytes(
  array_len : Int,
  raw_bytes : Bytes
) -> UnrecognizedFields {
  {
    format: UnrecognizedFormat::Bytes,
    array_len,
    values: raw_bytes,
  }
}

pub struct UnrecognizedVariant {
  format : UnrecognizedFormat
  number : Int
  value : Bytes
}

pub fn unrecognized_variant_from_bytes(
  number : Int,
  raw_bytes : Bytes
) -> UnrecognizedVariant {
  {
    format: UnrecognizedFormat::Bytes,
    number,
    value: raw_bytes,
  }
}

pub fn unrecognized_variant_from_json(
  number : Int,
  json_bytes : Bytes
) -> UnrecognizedVariant {
  {
    format: UnrecognizedFormat::DenseJson,
    number,
    value: json_bytes,
  }
}

pub impl Eq for UnrecognizedFields with equal(self, other) {
  self.format == other.format &&
  self.array_len == other.array_len &&
  self.values == other.values
}

pub impl Debug for UnrecognizedFields with to_repr(self) {
  Debug::to_repr(self.format)
}

pub impl Eq for UnrecognizedVariant with equal(self, other) {
  self.format == other.format &&
  self.number == other.number &&
  self.value == other.value
}

pub impl Debug for UnrecognizedVariant with to_repr(self) {
  Debug::to_repr(self.format)
}
