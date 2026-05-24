pub enum KeepOrSet[T] {
  Keep
  Set(T)
} derive(Eq, Debug)

pub fn[T] keep_or_set_keep() -> KeepOrSet[T] {
  KeepOrSet::Keep
}

pub fn[T] keep_or_set_set(value : T) -> KeepOrSet[T] {
  KeepOrSet::Set(value)
}
