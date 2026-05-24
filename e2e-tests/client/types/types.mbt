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

// Runtime aliases re-exported so generated code can keep a single @client alias.
pub type Recursive[T] = @runtime.Recursive[T]
pub type Timestamp = @runtime.Timestamp
pub type UnrecognizedFields[T] = @runtime.UnrecognizedFields[T]
pub type UnrecognizedVariant[T] = @runtime.UnrecognizedVariant[T]

pub fn[T] recursive_default() -> Recursive[T] {
	@runtime.recursive_default()
}

pub fn[T] unrecognized_variant_default() -> UnrecognizedVariant[T] {
	@runtime.unrecognized_variant_from_bytes(0, Bytes::default())
}

pub fn timestamp_default() -> Timestamp {
	@runtime.timestamp_from_unix_millis(0L)
}
