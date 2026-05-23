test "serializers_test_bool_dense_json_smoke" {
  let s = bool_serializer()
  assert_eq(s.to_dense_json(true), "1")
  assert_eq(s.to_dense_json(false), "0")
}
