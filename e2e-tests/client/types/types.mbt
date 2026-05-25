// Primitive aliases exposed for generated code.
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

// Runtime aliases re-exported so generated code can keep a single @client alias.
pub type Recursive[T] = @runtime.Recursive[T]
pub type Method[T, U] = @runtime.Method[T, U]
pub type Timestamp = @runtime.Timestamp
pub type UnrecognizedFields = @runtime.UnrecognizedFields
pub type UnrecognizedVariant = @runtime.UnrecognizedVariant
pub type KeyedVectorSpec[T, K] = @runtime.KeyedVectorSpec[T, K]
pub type KeyedVector[T, K] = @runtime.KeyedVector[T, K]
pub type KeepOrSet[T] = @runtime.KeepOrSet[T]

pub fn[T] recursive_default() -> Recursive[T] {
	@runtime.recursive_default()
}

pub fn[T] keep_or_set_keep() -> KeepOrSet[T] {
	@runtime.keep_or_set_keep()
}

pub fn unrecognized_variant_default() -> UnrecognizedVariant {
	@runtime.unrecognized_variant_from_bytes(0, Bytes::default())
}

pub let unrecognized_values_drop : () -> @runtime.UnrecognizedValues =
	@runtime.unrecognized_values_drop

pub let unrecognized_values_keep : () -> @runtime.UnrecognizedValues =
	@runtime.unrecognized_values_keep

pub fn timestamp_default() -> Timestamp {
	@runtime.Timestamp::from_unix_millis(0L)
}
