pub(all) struct KeyedVectorSpec[T, K] {
  get_key : (T) -> K
  key_extractor : String
  default_item : T
}

pub struct KeyedVector[T, K] {
  vector : @immut_vector.Vector[T]
  priv spec : KeyedVectorSpec[T, K]
  priv mut index : @hashmap.HashMap[K, T]?
}

pub fn[T, K] KeyedVector::new(
  vector : @immut_vector.Vector[T],
  spec : KeyedVectorSpec[T, K],
) -> KeyedVector[T, K] {
  { vector, spec, index: None }
}

pub fn[T, K] KeyedVector::from_array(
  items : Array[T],
  spec : KeyedVectorSpec[T, K],
) -> KeyedVector[T, K] {
  KeyedVector::new(@immut_vector.Vector::from_array(items), spec)
}

pub fn[T, K] KeyedVector::empty(spec : KeyedVectorSpec[T, K]) -> KeyedVector[T, K] {
  KeyedVector::new(@immut_vector.Vector::new(), spec)
}

fn[T, K] KeyedVector::has_index(self : KeyedVector[T, K]) -> Bool {
  match self.index {
    Some(_) => true
    None => false
  }
}

fn[T, K : Hash + Eq] KeyedVector::build_index(self : KeyedVector[T, K]) -> @hashmap.HashMap[K, T] {
  let index : @hashmap.HashMap[K, T] = @hashmap.HashMap([], capacity=self.vector.length())
  for item in self.vector.iter() {
    let key = (self.spec.get_key)(item)
    // Keep first occurrence for duplicate keys.
    if !index.contains(key) {
      index.set(key, item)
    }
  }
  index
}

fn[T, K : Hash + Eq] KeyedVector::ensure_index(self : KeyedVector[T, K]) -> @hashmap.HashMap[K, T] {
  match self.index {
    Some(index) => index
    None => {
      // Benign race: concurrent calls may build twice, but memory stays safe.
      let built = self.build_index()
      self.index = Some(built)
      built
    }
  }
}

pub fn[T, K : Hash + Eq] KeyedVector::find_by_key(self : KeyedVector[T, K], key : K) -> T? {
  self.ensure_index().get(key)
}

pub fn[T, K : Hash + Eq] KeyedVector::find_by_key_or_default(
  self : KeyedVector[T, K],
  key : K,
) -> T {
  match self.find_by_key(key) {
    Some(v) => v
    None => self.spec.default_item
  }
}

priv struct MockItem {
  key : String
  value : Int
}

fn mock_spec() -> KeyedVectorSpec[MockItem, String] {
  KeyedVectorSpec::{
    get_key: fn(item : MockItem) { item.key },
    key_extractor: "key",
    default_item: { key: "", value: 0 },
  }
}

fn[T : Eq] assert_eq_kv(lhs : T, rhs : T) -> Unit {
  if lhs != rhs {
    panic()
  }
}

test "keyed_vector_starts_without_index" {
  let kv = KeyedVector::from_array([{ key: "a", value: 1 }], mock_spec())
  assert_eq_kv(kv.has_index(), false)
}

test "find_by_key_builds_index_and_returns_value" {
  let kv = KeyedVector::from_array(
    [{ key: "a", value: 1 }, { key: "b", value: 2 }],
    mock_spec(),
  )
  match kv.find_by_key("b") {
    Some(v) => assert_eq_kv(v.value, 2)
    None => panic()
  }
  assert_eq_kv(kv.has_index(), true)
}

test "find_by_key_returns_none_when_missing" {
  let kv = KeyedVector::from_array([{ key: "a", value: 1 }], mock_spec())
  assert_eq_kv(kv.find_by_key("missing") is None, true)
}

test "find_by_key_keeps_first_duplicate" {
  let kv = KeyedVector::from_array(
    [{ key: "dup", value: 1 }, { key: "dup", value: 2 }],
    mock_spec(),
  )
  match kv.find_by_key("dup") {
    Some(v) => assert_eq_kv(v.value, 1)
    None => panic()
  }
}

test "find_by_key_or_default_uses_spec_default_item" {
  let kv = KeyedVector::from_array([{ key: "a", value: 1 }], mock_spec())
  let v = kv.find_by_key_or_default("missing")
  assert_eq_kv(v.key, "")
  assert_eq_kv(v.value, 0)
}
