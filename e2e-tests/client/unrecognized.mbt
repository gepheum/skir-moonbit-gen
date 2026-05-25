pub struct UnrecognizedFields {
  priv format : UnrecognizedFormat
  priv array_len : Int
}

pub struct UnrecognizedVariant {
  priv format : UnrecognizedFormat
  priv number : Int
}

priv enum UnrecognizedFormat {
  DenseJson(Json)
  Bytes(Bytes)
} derive(Eq, Debug)

fn unrecognized_fields_from_json(
  array_len : Int,
  json : Json
) -> UnrecognizedFields {
  {
    format: UnrecognizedFormat::DenseJson(json),
    array_len,
  }
}

fn unrecognized_fields_from_bytes(
  array_len : Int,
  raw_bytes : Bytes
) -> UnrecognizedFields {
  {
    format: UnrecognizedFormat::Bytes(raw_bytes),
    array_len,
  }
}

fn UnrecognizedFields::array_len(self : UnrecognizedFields) -> Int {
  self.array_len
}

fn UnrecognizedFields::dense_json(self : UnrecognizedFields) -> Json? {
  match self.format {
    UnrecognizedFormat::DenseJson(json) => Some(json)
    _ => None
  }
}

fn UnrecognizedFields::bytes(self : UnrecognizedFields) -> Bytes? {
  match self.format {
    UnrecognizedFormat::Bytes(bytes) => Some(bytes)
    _ => None
  }
}

fn unrecognized_variant_from_bytes(
  number : Int,
  raw_bytes : Bytes
) -> UnrecognizedVariant {
  {
    format: UnrecognizedFormat::Bytes(raw_bytes),
    number,
  }
}

fn unrecognized_variant_from_json(
  number : Int,
  json : Json
) -> UnrecognizedVariant {
  {
    format: UnrecognizedFormat::DenseJson(json),
    number,
  }
}

fn UnrecognizedVariant::number(self : UnrecognizedVariant) -> Int {
  self.number
}

fn UnrecognizedVariant::dense_json(self : UnrecognizedVariant) -> Json? {
  match self.format {
    UnrecognizedFormat::DenseJson(json) => Some(json)
    _ => None
  }
}

fn UnrecognizedVariant::bytes(self : UnrecognizedVariant) -> Bytes? {
  match self.format {
    UnrecognizedFormat::Bytes(bytes) => Some(bytes)
    _ => None
  }
}

pub impl Eq for UnrecognizedFields with equal(self, other) {
  self.format == other.format &&
  self.array_len == other.array_len
}

pub impl Debug for UnrecognizedFields with to_repr(self) {
  Debug::to_repr(self.format)
}

pub impl Eq for UnrecognizedVariant with equal(self, other) {
  self.format == other.format &&
  self.number == other.number
}

pub impl Debug for UnrecognizedVariant with to_repr(self) {
  Debug::to_repr(self.format)
}
