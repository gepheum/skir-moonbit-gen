priv struct StructFieldEntry[T] {
  number : Int
  name : String
  doc : String
  field_type : TypeSignature
  is_field_default : (T) -> Bool
  field_to_json : (T, StringBuilder, Bool, String) -> Unit
  field_from_json : (T, Json, UnrecognizedValues) -> Result[Unit, String]
  encode_field : (T, OutputStream) -> OutputStream
  decode_field : (T, InputStream, UnrecognizedValues) -> Result[InputStream, String]
}

pub struct StructAdapter[T] {
  module_path : String
  qualified_name : String
  doc : String
  default_value : () -> T
  get_unrecognized : (T) -> UnrecognizedFields?
  set_unrecognized : (T, UnrecognizedFields?) -> Unit
  priv ordered_entries : Array[StructFieldEntry[T]]
  priv name_to_index : @hashmap.HashMap[String, Int]
  priv slot_to_index : Array[Int?]
  priv removed_numbers : Array[Int]
}

pub fn[T] StructAdapter::new(
  module_path : String,
  qualified_name : String,
  doc : String,
  default_value : () -> T,
  get_unrecognized : (T) -> UnrecognizedFields?,
  set_unrecognized : (T, UnrecognizedFields?) -> Unit,
) -> StructAdapter[T] {
  {
    module_path,
    qualified_name,
    doc,
    default_value,
    get_unrecognized,
    set_unrecognized,
    ordered_entries: [],
    name_to_index: @hashmap.HashMap([], capacity=16),
    slot_to_index: [],
    removed_numbers: [],
  }
}

pub fn[T, V] StructAdapter::add_field(
  self : StructAdapter[T],
  name : String,
  number : Int,
  serializer : Serializer[V],
  getter : (T) -> V,
  setter : (T, V) -> Unit,
  doc : String,
) -> Unit {
  let entry : StructFieldEntry[T] = {
    number,
    name,
    doc,
    field_type: serializer.type_descriptor().root_type,
    is_field_default: fn(input : T) { serializer.is_default(getter(input)) },
    field_to_json: fn(input : T, out : StringBuilder, readable : Bool, _indent : String) {
      let value = getter(input)
      if readable {
        out.write_string(serializer.to_readable_json(value).stringify())
      } else {
        out.write_string(serializer.to_dense_json(value))
      }
    },
    field_from_json: fn(input : T, json : Json, policy : UnrecognizedValues) {
      match serializer.from_json(json.stringify(), policy) {
        Ok(v) => {
          setter(input, v)
          Ok(())
        }
        Err(e) => Err(e)
      }
    },
    encode_field: fn(input : T, out : OutputStream) { (serializer.adapter.encode)(getter(input), out) },
    decode_field: fn(input : T, in0 : InputStream, policy : UnrecognizedValues) {
      match (serializer.adapter.decode)(in0, policy) {
        Ok((v, tail)) => {
          setter(input, v)
          Ok(tail)
        }
        Err(e) => Err(e)
      }
    },
  }
  self.ordered_entries.push(entry)
}

pub fn[T] StructAdapter::add_removed_number(self : StructAdapter[T], number : Int) -> Unit {
  self.removed_numbers.push(number)
}

pub fn[T] StructAdapter::finalize(self : StructAdapter[T]) -> Unit {
  self.name_to_index.clear()
  let mut max_field = -1
  for i in 0..<self.ordered_entries.length() {
    let e = self.ordered_entries[i]
    self.name_to_index.set(e.name, i)
    if e.number > max_field {
      max_field = e.number
    }
  }
  let mut max_removed = -1
  for n in self.removed_numbers {
    if n > max_removed {
      max_removed = n
    }
  }
  let max_number = if max_field > max_removed { max_field } else { max_removed }
  self.slot_to_index.clear()
  for _ in 0..<(max_number + 1) {
    self.slot_to_index.push(None)
  }
  for i in 0..<self.ordered_entries.length() {
    let n = self.ordered_entries[i].number
    if n >= 0 && n < self.slot_to_index.length() {
      self.slot_to_index[n] = Some(i)
    }
  }
}

fn[T] StructAdapter::get_slot_count(self : StructAdapter[T], input : T) -> Int {
  let mut max_non_default = -1
  for e in self.ordered_entries {
      if !(e.is_field_default)(input) && e.number > max_non_default {
      max_non_default = e.number
    }
  }
  max_non_default + 1
}

fn[T] StructAdapter::to_dense_json_impl(self : StructAdapter[T], input : T, out : StringBuilder) -> Unit {
  let unrecognized = (self.get_unrecognized)(input)
  let mut total_slot_count = self.get_slot_count(input)
  let mut extra_json = ""

  match unrecognized {
    Some(u) if u.format == UnrecognizedFormat::DenseJson => {
      total_slot_count = u.array_len
        extra_json = struct_bytes_to_utf8_or_default(u.values)
    }
    _ => ()
  }

  let recognized_max = self.slot_to_index.length()
  out.write_char('[')
  for i in 0..<struct_min(total_slot_count, recognized_max) {
    if i > 0 {
      out.write_char(',')
    }
    match self.slot_to_index[i] {
      Some(idx) => (self.ordered_entries[idx].field_to_json)(input, out, false, "")
      None => out.write_char('0')
    }
  }

  if total_slot_count > recognized_max && extra_json != "" {
    if recognized_max > 0 {
      out.write_char(',')
    }
    out.write_string(extra_json)
  }
  out.write_char(']')
}

fn[T] StructAdapter::to_readable_json_impl(
  self : StructAdapter[T],
  input : T,
  indent : String,
  out : StringBuilder,
) -> Unit {
  out.write_char('{')
  let child_indent = indent + "  "
  let mut first = true
  for e in self.ordered_entries {
    if (e.is_field_default)(input) {
      continue
    }
    if !first {
      out.write_char(',')
    }
    first = false
    out.write_string(child_indent)
      struct_append_json_string(out, e.name)
    out.write_string(": ")
    (e.field_to_json)(input, out, true, child_indent)
  }
  if !first {
    out.write_string(indent)
  }
  out.write_char('}')
}

fn[T] StructAdapter::from_dense_json_impl(
  self : StructAdapter[T],
  arr : Array[Json],
  policy : UnrecognizedValues,
) -> Result[T, String] {
  let value = (self.default_value)()
  for e in self.ordered_entries {
    let n = e.number
    if n < 0 || n >= arr.length() {
      continue
    }
    match (e.field_from_json)(value, arr[n], policy) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }

  if struct_should_keep_unrecognized(policy) {
    let recognized_max = self.slot_to_index.length()
    if arr.length() > recognized_max {
      let mut extra = ""
      let mut first = true
      for i in recognized_max..<arr.length() {
        if !first {
          extra = extra + ","
        }
        first = false
        extra = extra + arr[i].stringify()
      }
      let ud = unrecognized_fields_from_json(arr.length(), @utf8.encode(extra))
      (self.set_unrecognized)(value, Some(ud))
    }
  }

  Ok(value)
}

fn[T] StructAdapter::from_readable_json_impl(
  self : StructAdapter[T],
  json : Json,
  policy : UnrecognizedValues,
) -> Result[T, String] {
  match json {
    Json::Object(obj) => {
      let value = (self.default_value)()
      for e in self.ordered_entries {
        match obj.get(e.name) {
          Some(v) =>
            match (e.field_from_json)(value, v, policy) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          None => ()
        }
      }
      Ok(value)
    }
    _ => Ok((self.default_value)())
  }
}

fn struct_bytes_to_utf8_or_default(bytes : Bytes) -> String {
  try {
    @utf8.decode(bytes[:])
  } catch {
    _ => ""
  }
}

fn struct_int_array_to_bytes(bytes : Array[Int]) -> Bytes {
  let out : Array[Byte] = []
  for b in bytes {
    out.push(b.to_byte())
  }
  Bytes::from_array(out)
}

fn struct_append_json_string(builder : StringBuilder, s : String) -> Unit {
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

fn struct_should_keep_unrecognized(policy : UnrecognizedValues) -> Bool {
  match policy {
    UnrecognizedValues::Keep => true
    UnrecognizedValues::Drop => false
  }
}

fn struct_min(a : Int, b : Int) -> Int {
  if a < b { a } else { b }
}

fn skip_n_values(input : InputStream, n : Int) -> Result[InputStream, String] {
  let mut cur = input
  for _ in 0..<n {
    match skip_value(cur) {
      Ok(next) => cur = next
      Err(e) => return Err(e)
    }
  }
  Ok(cur)
}

fn take_n_bytes(input : InputStream, n : Int) -> Result[InputStream, String] {
  let mut cur = input
  for _ in 0..<n {
    match cur.read_int() {
      Ok((_b, next)) => cur = next
      Err(e) => return Err(e)
    }
  }
  Ok(cur)
}

fn skip_value(input : InputStream) -> Result[InputStream, String] {
  match input.read_int() {
    Ok((wire, rest)) =>
      match wire {
        0..=231 => Ok(rest)
        242 => Ok(rest)
        244 => Ok(rest)
        246 => Ok(rest)
        255 => Ok(rest)
        232 | 236 => take_n_bytes(rest, 2)
        233 | 237 | 240 => take_n_bytes(rest, 4)
        234 | 238 | 239 | 241 => take_n_bytes(rest, 8)
        235 => take_n_bytes(rest, 1)
        243 | 245 =>
          match decode_number_with_tail(rest) {
            Ok((n, tail)) if n >= 0 => take_n_bytes(tail, n.to_int())
            Ok(_) => Err("unexpected negative length in skip_value")
            Err(e) => Err(e)
          }
        247..=249 => skip_n_values(rest, wire - 246)
        250 =>
          match decode_number_with_tail(rest) {
            Ok((n, tail)) if n >= 0 => skip_n_values(tail, n.to_int())
            Ok(_) => Err("unexpected negative array length in skip_value")
            Err(e) => Err(e)
          }
        251..=254 => skip_value(rest)
        _ => Ok(rest)
      }
    Err(e) => Err(e)
  }
}

pub fn[T] StructAdapter::serializer(self : StructAdapter[T]) -> Serializer[T] {
  new_serializer({
    is_default: fn(input : T) {
      match (self.get_unrecognized)(input) {
        Some(_) => false
        None => {
          for e in self.ordered_entries {
            if !(e.is_field_default)(input) {
              return false
            }
          }
          true
        }
      }
    },
    to_dense_json: fn(input : T, out : StringBuilder) {
      self.to_dense_json_impl(input, out)
    },
    to_readable_json: fn(input : T) {
      let builder = StringBuilder::new()
      self.to_readable_json_impl(input, "", builder)
      parse_json(builder.to_string())
    },
    from_json: fn(json : Json, policy : UnrecognizedValues) {
      match json {
        Json::Array(arr) => self.from_dense_json_impl(arr, policy)
        Json::Object(_) => self.from_readable_json_impl(json, policy)
        _ => Ok((self.default_value)())
      }
    },
    encode: fn(input : T, out : OutputStream) {
      let unrecognized = (self.get_unrecognized)(input)
      let mut total_slot_count = self.get_slot_count(input)
      let mut extra_bytes = Bytes::default()
      match unrecognized {
        Some(u) if u.format == UnrecognizedFormat::Bytes => {
          total_slot_count = u.array_len
          extra_bytes = u.values
        }
        _ => ()
      }

      let mut cur = out
      if total_slot_count <= 3 {
        cur = cur.write_int(246 + total_slot_count)
      } else {
        cur = cur.write_ints([250, ..encode_u32_le(total_slot_count)])
      }

      let recognized_count = self.slot_to_index.length()
      for i in 0..<struct_min(total_slot_count, recognized_count) {
        match self.slot_to_index[i] {
          Some(idx) => {
            cur = (self.ordered_entries[idx].encode_field)(input, cur)
          }
          None => {
            cur = cur.write_int(0)
          }
        }
      }
      cur.write_bytes(extra_bytes)
    },
    decode: fn(input : InputStream, policy : UnrecognizedValues) {
      let mut cur = input
      match cur.read_int() {
        Ok((wire, rest)) => {
          cur = rest
          if wire == 0 || wire == 246 {
            return Ok(((self.default_value)(), cur))
          }

          let slot_count =
            if wire == 250 {
              match decode_number_with_tail(cur) {
                Ok((n, tail)) if n >= 0 => {
                  cur = tail
                  n.to_int()
                }
                Ok(_) => return Err("unexpected negative struct slot count")
                Err(e) => return Err(e)
              }
            } else {
              wire - 246
            }

          let value = (self.default_value)()
          let recognized_count = self.slot_to_index.length()
          let slots_to_fill = struct_min(slot_count, recognized_count)

          for i in 0..<slots_to_fill {
            match self.slot_to_index[i] {
              Some(idx) =>
                match (self.ordered_entries[idx].decode_field)(value, cur, policy) {
                  Ok(next_stream) => { cur = next_stream }
                  Err(e) => return Err(e)
                }
              None =>
                match skip_value(cur) {
                  Ok(next) => cur = next
                  Err(e) => return Err(e)
                }
            }
          }

          if slot_count > recognized_count {
            if struct_should_keep_unrecognized(policy) {
              let before = cur.remaining_int_array()
              for _ in recognized_count..<slot_count {
                match skip_value(cur) {
                  Ok(next) => cur = next
                  Err(e) => return Err(e)
                }
              }
              let after_len = cur.remaining_int_array().length()
              let consumed_len = before.length() - after_len
              let captured = before[0:consumed_len].iter().to_array()
              (self.set_unrecognized)(
                value,
                Some(
                  unrecognized_fields_from_bytes(
                    slot_count,
                    struct_int_array_to_bytes(captured),
                  ),
                ),
              )
            } else {
              for _ in recognized_count..<slot_count {
                match skip_value(cur) {
                  Ok(next) => cur = next
                  Err(e) => return Err(e)
                }
              }
            }
          }

          Ok((value, cur))
        }
        Err(e) => Err(e)
      }
    },
    type_descriptor: fn() {
      let fields : Array[StructField] = []
      for e in self.ordered_entries {
        fields.push({
          name: e.name,
          number: e.number,
          field_type: e.field_type,
          doc: e.doc,
        })
      }
      {
        root_type: TypeSignature::Record(self.module_path + "." + self.qualified_name),
        records: [
          RecordDescriptor::Struct({
            record_id: self.module_path + "." + self.qualified_name,
            doc: self.doc,
            removed_numbers: self.removed_numbers,
            fields,
          }),
        ],
      }
    },
  })
}
