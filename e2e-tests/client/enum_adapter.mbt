priv enum EnumAnyEntry {
  Removed
  Constant(Int)
  Wrapper(Int)
}

priv struct EnumVariantEntry[T] {
  constant : () -> T?
  wrapper_default : () -> T
  variant_to_json : (T, StringBuilder, Bool, String) -> Unit
  encode_value : (T, OutputStream) -> OutputStream
  wrap_from_json : (Json, UnrecognizedValues) -> Result[T, String]
  wrap_decode : (InputStream, UnrecognizedValues) -> Result[(T, InputStream), String]
  descriptor_variant : EnumVariant
}

pub struct EnumAdapter[T] {
  module_path : String
  qualified_name : String
  doc : String
  default_value : T
  get_kind_ordinal : (T) -> Int
  wrap_unrecognized : (UnrecognizedVariant[T]) -> T
  get_unrecognized : (T) -> UnrecognizedVariant[T]?
  priv number_to_entry : @hashmap.HashMap[Int, EnumAnyEntry]
  priv removed_numbers : Array[Int]
  priv name_to_kind_ordinal : @hashmap.HashMap[String, Int]
  priv kind_ordinal_to_entry : Array[EnumVariantEntry[T]?]
  priv desc_variants : Array[EnumVariant]
}

pub fn[T] enum_adapter_new(
  module_path : String,
  qualified_name : String,
  doc : String,
  default_value : T,
  get_kind_ordinal : (T) -> Int,
  wrap_unrecognized : (UnrecognizedVariant[T]) -> T,
  get_unrecognized : (T) -> UnrecognizedVariant[T]?,
) -> EnumAdapter[T] {
  {
    module_path,
    qualified_name,
    doc,
    default_value,
    get_kind_ordinal,
    wrap_unrecognized,
    get_unrecognized,
    number_to_entry: @hashmap.HashMap([], capacity=16),
    removed_numbers: [],
    name_to_kind_ordinal: @hashmap.HashMap([], capacity=16),
    kind_ordinal_to_entry: [None],
    desc_variants: [],
  }
}

fn[T] EnumAdapter::set_kind_ordinal_entry(
  self : EnumAdapter[T],
  kind_ordinal : Int,
  entry : EnumVariantEntry[T],
) -> Unit {
  while self.kind_ordinal_to_entry.length() <= kind_ordinal {
    self.kind_ordinal_to_entry.push(None)
  }
  self.kind_ordinal_to_entry[kind_ordinal] = Some(entry)
}

pub fn[T] EnumAdapter::add_constant_variant(
  self : EnumAdapter[T],
  name : String,
  number : Int,
  kind_ordinal : Int,
  doc : String,
  instance : T,
) -> Unit {
  self.number_to_entry.set(number, EnumAnyEntry::Constant(kind_ordinal))
  self.name_to_kind_ordinal.set(name, kind_ordinal)
  let upper = name.to_upper()
  if upper != name {
    self.name_to_kind_ordinal.set(upper, kind_ordinal)
  }
  let lower = name.to_lower()
  if lower != name {
    self.name_to_kind_ordinal.set(lower, kind_ordinal)
  }

  let entry : EnumVariantEntry[T] = {
    constant: fn() { Some(instance) },
    wrapper_default: fn() { self.default_value },
    variant_to_json: fn(_input : T, out : StringBuilder, readable : Bool, _indent : String) {
      if readable {
        enum_append_json_string(out, name)
      } else {
        out.write_string(number.to_string())
      }
    },
    encode_value: fn(_input : T, out0 : OutputStream) {
      let out = out0
      out.write_ints(encode_i32(number))
    },
    wrap_from_json: fn(_json, _policy) { Err("variant '" + name + "' is a constant, not a wrapper") },
    wrap_decode: fn(_input, _policy) { Err("variant '" + name + "' is a constant, not a wrapper") },
    descriptor_variant: EnumVariant::Constant({ name, number, doc }),
  }
  self.set_kind_ordinal_entry(kind_ordinal, entry)
  self.desc_variants.push(entry.descriptor_variant)
}

pub fn[T, V] EnumAdapter::add_wrapper_variant(
  self : EnumAdapter[T],
  name : String,
  number : Int,
  kind_ordinal : Int,
  serializer : Serializer[V],
  doc : String,
  wrap : (V) -> T,
  get_value : (T) -> V,
) -> Unit {
  self.number_to_entry.set(number, EnumAnyEntry::Wrapper(kind_ordinal))
  self.name_to_kind_ordinal.set(name, kind_ordinal)

  let entry : EnumVariantEntry[T] = {
    constant: fn() { None },
    wrapper_default: fn() {
      match serializer.from_json("0", UnrecognizedValues::Drop) {
        Ok(v) => wrap(v)
        Err(_) => self.default_value
      }
    },
    variant_to_json: fn(input : T, out : StringBuilder, readable : Bool, indent : String) {
      let value = get_value(input)
      if readable {
        let child = indent + "  "
        out.write_char('{')
        out.write_string(child)
        out.write_string("\"kind\": ")
        enum_append_json_string(out, name)
        out.write_char(',')
        out.write_string(child)
        out.write_string("\"value\": ")
        out.write_string(serializer.to_readable_json(value).stringify())
        out.write_string(indent)
        out.write_char('}')
      } else {
        out.write_char('[')
        out.write_string(number.to_string())
        out.write_char(',')
        out.write_string(serializer.to_dense_json(value))
        out.write_char(']')
      }
    },
    encode_value: fn(input : T, out0 : OutputStream) {
      let mut out = out0
      if number >= 1 && number <= 4 {
        out = out.write_int(250 + number)
      } else {
        out = out.write_int(248)
        out = out.write_ints(encode_u32_le(number))
      }
      (serializer.adapter.encode)(get_value(input), out)
    },
    wrap_from_json: fn(json : Json, policy : UnrecognizedValues) {
      match serializer.from_json(json.stringify(), policy) {
        Ok(v) => Ok(wrap(v))
        Err(e) => Err(e)
      }
    },
    wrap_decode: fn(input : InputStream, policy : UnrecognizedValues) {
      match (serializer.adapter.decode)(input, policy) {
        Ok((v, tail)) => Ok((wrap(v), tail))
        Err(e) => Err(e)
      }
    },
    descriptor_variant: EnumVariant::Wrapper({
      name,
      number,
      variant_type: serializer.type_descriptor().root_type,
      doc,
    }),
  }

  self.set_kind_ordinal_entry(kind_ordinal, entry)
  self.desc_variants.push(entry.descriptor_variant)
}

pub fn[T] EnumAdapter::add_removed_number(self : EnumAdapter[T], number : Int) -> Unit {
  self.number_to_entry.set(number, EnumAnyEntry::Removed)
  self.removed_numbers.push(number)
}

pub fn[T] EnumAdapter::finalize(self : EnumAdapter[T]) -> Unit {
  self.name_to_kind_ordinal.set("UNKNOWN", 0)
  self.name_to_kind_ordinal.set("unknown", 0)
}

fn[T] EnumAdapter::contains_removed(self : EnumAdapter[T], number : Int) -> Bool {
  for n in self.removed_numbers {
    if n == number {
      return true
    }
  }
  false
}

fn enum_is_keep(policy : UnrecognizedValues) -> Bool {
  match policy {
    UnrecognizedValues::Keep => true
    UnrecognizedValues::Drop => false
  }
}

fn[T] EnumAdapter::entry_at_kind(self : EnumAdapter[T], ko : Int) -> EnumVariantEntry[T]? {
  if ko >= 0 && ko < self.kind_ordinal_to_entry.length() {
    self.kind_ordinal_to_entry[ko]
  } else {
    None
  }
}

fn enum_bytes_to_utf8_or_default(bytes : Bytes) -> String {
  try {
    @utf8.decode(bytes[:])
  } catch {
    _ => ""
  }
}

fn enum_int_array_to_bytes(bytes : Array[Int]) -> Bytes {
  let out : Array[Byte] = []
  for b in bytes {
    out.push(b.to_byte())
  }
  Bytes::from_array(out)
}

fn enum_append_json_string(builder : StringBuilder, s : String) -> Unit {
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
      _ => builder.write_char(ch)
    }
  }
  builder.write_char('"')
}

pub fn[T] EnumAdapter::serializer(self : EnumAdapter[T]) -> Serializer[T] {
  new_serializer({
    is_default: fn(input : T) { (self.get_kind_ordinal)(input) == 0 },
    to_dense_json: fn(input : T, out : StringBuilder) {
      let ko = (self.get_kind_ordinal)(input)
      if ko == 0 {
        match (self.get_unrecognized)(input) {
          Some(u) => {
            if u.format == UnrecognizedFormat::DenseJson && !u.value.is_empty() {
              out.write_string(enum_bytes_to_utf8_or_default(u.value))
              return
            }
            if u.format == UnrecognizedFormat::Bytes {
              match self.number_to_entry.get(u.number) {
                Some(_) => {
                  out.write_string(u.number.to_string())
                  return
                }
                None => ()
              }
            }
          }
          None => ()
        }
        out.write_char('0')
        return
      }

      match self.entry_at_kind(ko) {
        Some(e) => (e.variant_to_json)(input, out, false, "")
        None => out.write_char('0')
      }
    },
    to_readable_json: fn(input : T) {
      let ko = (self.get_kind_ordinal)(input)
      let builder = StringBuilder::new()
      if ko == 0 {
        enum_append_json_string(builder, "unknown")
      } else {
        match self.entry_at_kind(ko) {
          Some(e) => (e.variant_to_json)(input, builder, true, "")
          None => enum_append_json_string(builder, "unknown")
        }
      }
      parse_json(builder.to_string())
    },
    from_json: fn(json : Json, policy : UnrecognizedValues) {
      let keep = enum_is_keep(policy)
      match json {
        Json::Number(n, ..) => {
          let number = n.to_int()
          match self.number_to_entry.get(number) {
            Some(EnumAnyEntry::Removed) => Ok(self.default_value)
            Some(EnumAnyEntry::Constant(ko)) =>
              match self.entry_at_kind(ko) {
                Some(e) =>
                  match (e.constant)() {
                    Some(v) => Ok(v)
                    None => Ok(self.default_value)
                  }
                None => Ok(self.default_value)
              }
            Some(EnumAnyEntry::Wrapper(ko)) =>
              match self.entry_at_kind(ko) {
                Some(e) => Ok((e.wrapper_default)())
                None => Ok(self.default_value)
              }
            None =>
              if keep {
                Ok((self.wrap_unrecognized)(unrecognized_variant_from_json(number, @utf8.encode(json.stringify()))))
              } else {
                Ok(self.default_value)
              }
          }
        }
        Json::True =>
          match self.number_to_entry.get(1) {
            Some(EnumAnyEntry::Constant(ko)) =>
              match self.entry_at_kind(ko) {
                Some(e) =>
                  match (e.constant)() {
                    Some(v) => Ok(v)
                    None => Ok(self.default_value)
                  }
                None => Ok(self.default_value)
              }
            _ => Ok(self.default_value)
          }
        Json::False =>
          match self.number_to_entry.get(0) {
            Some(EnumAnyEntry::Constant(ko)) =>
              match self.entry_at_kind(ko) {
                Some(e) =>
                  match (e.constant)() {
                    Some(v) => Ok(v)
                    None => Ok(self.default_value)
                  }
                None => Ok(self.default_value)
              }
            _ => Ok(self.default_value)
          }
        Json::String(s) =>
          match self.name_to_kind_ordinal.get(s) {
            Some(ko) =>
              match self.entry_at_kind(ko) {
                Some(e) =>
                  match (e.constant)() {
                    Some(v) => Ok(v)
                    None => Ok((e.wrapper_default)())
                  }
                None => Ok(self.default_value)
              }
            None => Ok(self.default_value)
          }
        Json::Array(arr) if arr.length() == 2 => {
          let number =
            match arr[0] {
              Json::Number(n, ..) => n.to_int()
              _ => 0
            }
          match self.number_to_entry.get(number) {
            Some(EnumAnyEntry::Removed) => Ok(self.default_value)
            Some(EnumAnyEntry::Constant(ko)) =>
              match self.entry_at_kind(ko) {
                Some(e) =>
                  match (e.constant)() {
                    Some(v) => Ok(v)
                    None => Ok(self.default_value)
                  }
                None => Ok(self.default_value)
              }
            Some(EnumAnyEntry::Wrapper(ko)) =>
              match self.entry_at_kind(ko) {
                Some(e) => (e.wrap_from_json)(arr[1], policy)
                None => Ok(self.default_value)
              }
            None =>
              if keep {
                Ok((self.wrap_unrecognized)(unrecognized_variant_from_json(number, @utf8.encode(json.stringify()))))
              } else {
                Ok(self.default_value)
              }
          }
        }
        Json::Object(obj) => {
          let name =
            match obj.get("kind") {
              Some(Json::String(s)) => s
              _ => ""
            }
          let value_json_opt = obj.get("value")
          match self.name_to_kind_ordinal.get(name) {
            Some(ko) =>
              match self.entry_at_kind(ko) {
                Some(e) =>
                  match (e.constant)() {
                    Some(v) => Ok(v)
                    None =>
                      match value_json_opt {
                        Some(value_json) => (e.wrap_from_json)(value_json, policy)
                        None => (e.wrap_from_json)(parse_json("null"), policy)
                      }
                  }
                None => Ok(self.default_value)
              }
            None => Ok(self.default_value)
          }
        }
        _ => Ok(self.default_value)
      }
    },
    encode: fn(input : T, out0 : OutputStream) {
      let ko = (self.get_kind_ordinal)(input)
      if ko == 0 {
        match (self.get_unrecognized)(input) {
          Some(u) if u.format == UnrecognizedFormat::Bytes => {
            let out = out0
            out.write_bytes(u.value)
          }
          _ => out0.write_int(0)
        }
      } else {
        match self.entry_at_kind(ko) {
          Some(e) => (e.encode_value)(input, out0)
          None => out0.write_int(0)
        }
      }
    },
    decode: fn(input : InputStream, policy : UnrecognizedValues) {
      let keep = enum_is_keep(policy)
      let before = input.remaining_int_array()
      match input.read_int() {
        Ok((wire, rest)) => {
          if wire < 242 {
            match decode_number_body(wire, rest) {
              Ok((n, tail)) => {
                let number = n.to_int()
                match self.number_to_entry.get(number) {
                  Some(EnumAnyEntry::Removed) => Ok((self.default_value, tail))
                  Some(EnumAnyEntry::Constant(ko)) =>
                    match self.entry_at_kind(ko) {
                      Some(e) =>
                        match (e.constant)() {
                          Some(v) => Ok((v, tail))
                          None => Ok((self.default_value, tail))
                        }
                      None => Ok((self.default_value, tail))
                    }
                  Some(EnumAnyEntry::Wrapper(ko)) =>
                    match self.entry_at_kind(ko) {
                      Some(e) => Ok(((e.wrapper_default)(), tail))
                      None => Ok((self.default_value, tail))
                    }
                  None => {
                    if keep && !self.contains_removed(number) {
                      let consumed_len = before.length() - tail.remaining_int_array().length()
                      let captured = before[0:consumed_len]
                      Ok(((self.wrap_unrecognized)(unrecognized_variant_from_bytes(number, enum_int_array_to_bytes(captured.iter().to_array()))), tail))
                    } else {
                      Ok((self.default_value, tail))
                    }
                  }
                }
              }
              Err(e) => Err(e)
            }
          } else {
            let mut number = 0
            let mut cur = rest
            if wire == 248 {
              match decode_number_with_tail(cur) {
                Ok((n, tail)) => {
                  number = n.to_int()
                  cur = tail
                }
                Err(e) => return Err(e)
              }
            } else {
              number = wire - 250
            }

            match self.number_to_entry.get(number) {
              Some(EnumAnyEntry::Removed) =>
                match skip_value(cur) {
                  Ok(next) => Ok((self.default_value, next))
                  Err(e) => Err(e)
                }
              Some(EnumAnyEntry::Constant(ko)) =>
                match skip_value(cur) {
                  Ok(next) =>
                    match self.entry_at_kind(ko) {
                      Some(e) =>
                        match (e.constant)() {
                          Some(v) => Ok((v, next))
                          None => Ok((self.default_value, next))
                        }
                      None => Ok((self.default_value, next))
                    }
                  Err(e) => Err(e)
                }
              Some(EnumAnyEntry::Wrapper(ko)) =>
                match self.entry_at_kind(ko) {
                  Some(e) => (e.wrap_decode)(cur, policy)
                  None => Ok((self.default_value, cur))
                }
              None =>
                match skip_value(cur) {
                  Ok(next) => {
                    if keep && !self.contains_removed(number) {
                      let consumed_len = before.length() - next.remaining_int_array().length()
                      let captured = before[0:consumed_len]
                      Ok(((self.wrap_unrecognized)(unrecognized_variant_from_bytes(number, enum_int_array_to_bytes(captured.iter().to_array()))), next))
                    } else {
                      Ok((self.default_value, next))
                    }
                  }
                  Err(e) => Err(e)
                }
            }
          }
        }
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      {
        root_type: TypeSignature::Record(self.module_path + "." + self.qualified_name),
        records: [
          RecordDescriptor::Enum({
            record_id: self.module_path + "." + self.qualified_name,
            doc: self.doc,
            removed_numbers: self.removed_numbers,
            variants: self.desc_variants,
          }),
        ],
      }
    },
  })
}
