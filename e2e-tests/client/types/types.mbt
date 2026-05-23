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
pub type Timestamp = @runtime.Timestamp
pub type UnrecognizedFields = @runtime.UnrecognizedFields
pub type UnrecognizedVariant = @runtime.UnrecognizedVariant
