fn expect_ok_bool(r : Result[Bool, String]) -> Bool {
  match r {
    Ok(v) => v
    Err(_) => panic()
  }
}

test "to_json_dense_true" {
  assert_eq(bool_serializer().to_json(true, JsonFlavor::Dense), "1")
}

test "to_json_dense_false" {
  assert_eq(bool_serializer().to_json(false, JsonFlavor::Dense), "0")
}

test "to_json_readable_true" {
  assert_eq(bool_serializer().to_json(true, JsonFlavor::Readable), "true")
}

test "to_json_readable_false" {
  assert_eq(bool_serializer().to_json(false, JsonFlavor::Readable), "false")
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
