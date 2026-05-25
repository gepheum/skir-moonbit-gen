pub type Bool = @runtime.NativeBool
pub type Array[T] = @runtime.NativeArray[T]
pub type Int = @runtime.NativeInt
pub type Int64 = @runtime.NativeInt64
pub type UInt64 = @runtime.NativeUInt64
pub type Float = @runtime.NativeFloat
pub type Double = @runtime.NativeDouble
pub type String = @runtime.NativeString
pub type Bytes = @runtime.NativeBytes
pub type Vector[T] = @immut_vector.Vector[T]

pub type Recursive[T] = @runtime.Recursive[T]
pub type Method[T, U] = @runtime.Method[T, U]
pub type Timestamp = @runtime.Timestamp
pub type UnrecognizedFields = @runtime.UnrecognizedFields
pub type UnrecognizedVariant = @runtime.UnrecognizedVariant
pub type KeyedVectorSpec[T, K] = @runtime.KeyedVectorSpec[T, K]
pub type KeyedVector[T, K] = @runtime.KeyedVector[T, K]
pub type KeepOrSet[T] = @runtime.KeepOrSet[T]
pub type UnrecognizedValues = @runtime.UnrecognizedValues
pub type Serializer[T] = @runtime.Serializer[T]
pub type StructAdapter[T] = @runtime.StructAdapter[T]
pub type EnumAdapter[T] = @runtime.EnumAdapter[T]

pub fn[T] recursive_default() -> Recursive[T] {
	@runtime.recursive_default()
}

pub fn[T] keep_or_set_keep() -> KeepOrSet[T] {
	@runtime.keep_or_set_keep()
}

pub fn unrecognized_variant_default() -> UnrecognizedVariant {
	@runtime.unrecognized_variant_from_bytes(0, Bytes::default())
}

pub let unrecognized_values_drop : () -> UnrecognizedValues =
	@runtime.unrecognized_values_drop

pub let unrecognized_values_keep : () -> UnrecognizedValues =
	@runtime.unrecognized_values_keep

pub fn timestamp_default() -> Timestamp {
	@runtime.Timestamp::from_unix_millis(0L)
}

pub fn bool_serializer() -> Serializer[Bool] {
	@runtime.bool_serializer()
}

pub fn int32_serializer() -> Serializer[Int] {
	@runtime.int32_serializer()
}

pub fn int64_serializer() -> Serializer[Int64] {
	@runtime.int64_serializer()
}

pub fn hash64_serializer() -> Serializer[UInt64] {
	@runtime.hash64_serializer()
}

pub fn float32_serializer() -> Serializer[Float] {
	@runtime.float32_serializer()
}

pub fn float64_serializer() -> Serializer[Double] {
	@runtime.float64_serializer()
}

pub fn timestamp_serializer() -> Serializer[Timestamp] {
	@runtime.timestamp_serializer()
}

pub fn string_serializer() -> Serializer[String] {
	@runtime.string_serializer()
}

pub fn bytes_serializer() -> Serializer[Bytes] {
	@runtime.bytes_serializer()
}

pub fn[T] optional_serializer(other : Serializer[T]) -> Serializer[T?] {
	@runtime.optional_serializer(other)
}

pub fn[T] recursive_serializer(other : Serializer[T]) -> Serializer[Recursive[T]] {
	@runtime.recursive_serializer(other)
}

pub fn[T] vector_serializer(item_serializer : Serializer[T]) -> Serializer[@immut_vector.Vector[T]] {
	@runtime.vector_serializer(item_serializer)
}

pub fn[T] keyed_vector_serializer(
	item_serializer : Serializer[T],
	key_extractor : String,
) -> Serializer[@immut_vector.Vector[T]] {
	@runtime.keyed_vector_serializer(item_serializer, key_extractor)
}
