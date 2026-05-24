pub struct KeyedVector[T, K] {
  items : @immut_vector.Vector[T]
  key_of : (T) -> K
  mut index : @hashmap.HashMap[K, T]?
}

pub fn[T, K] KeyedVector::new(
  items : @immut_vector.Vector[T],
  key_of : (T) -> K,
) -> KeyedVector[T, K] {
  { items, key_of, index: None }
}

pub fn[T, K] keyed_vector_from_array(
  items : Array[T],
  key_of : (T) -> K,
) -> KeyedVector[T, K] {
  KeyedVector::new(@immut_vector.Vector::from_array(items), key_of)
}

pub fn[T, K] KeyedVector::items(self : KeyedVector[T, K]) -> @immut_vector.Vector[T] {
  self.items
}

pub fn[T, K] KeyedVector::length(self : KeyedVector[T, K]) -> Int {
  self.items.length()
}

pub fn[T, K] KeyedVector::is_empty(self : KeyedVector[T, K]) -> Bool {
  self.items.is_empty()
}

pub fn[T, K] KeyedVector::has_index(self : KeyedVector[T, K]) -> Bool {
  match self.index {
    Some(_) => true
    None => false
  }
}

fn[T, K : Hash + Eq] KeyedVector::build_index(self : KeyedVector[T, K]) -> @hashmap.HashMap[K, T] {
  let index : @hashmap.HashMap[K, T] = @hashmap.HashMap([], capacity=self.length())
  for item in self.items.iter() {
    let key = (self.key_of)(item)
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

priv struct MockItem {
  key : String
  value : Int
}

fn[T : Eq] assert_eq_kv(lhs : T, rhs : T) -> Unit {
  if lhs != rhs {
    panic()
  }
}

test "keyed_vector_starts_without_index" {
  let kv = keyed_vector_from_array([{ key: "a", value: 1 }], fn(item : MockItem) { item.key })
  assert_eq_kv(kv.has_index(), false)
}

test "find_by_key_builds_index_and_returns_value" {
  let kv = keyed_vector_from_array(
    [{ key: "a", value: 1 }, { key: "b", value: 2 }],
    fn(item : MockItem) { item.key },
  )
  match kv.find_by_key("b") {
    Some(v) => assert_eq_kv(v.value, 2)
    None => panic()
  }
  assert_eq_kv(kv.has_index(), true)
}

test "find_by_key_returns_none_when_missing" {
  let kv = keyed_vector_from_array([{ key: "a", value: 1 }], fn(item : MockItem) { item.key })
  assert_eq_kv(kv.find_by_key("missing") is None, true)
}

test "find_by_key_keeps_first_duplicate" {
  let kv = keyed_vector_from_array(
    [{ key: "dup", value: 1 }, { key: "dup", value: 2 }],
    fn(item : MockItem) { item.key },
  )
  match kv.find_by_key("dup") {
    Some(v) => assert_eq_kv(v.value, 1)
    None => panic()
  }
}
