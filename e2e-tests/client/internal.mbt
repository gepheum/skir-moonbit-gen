pub fn timestamp_default() -> Timestamp {
	Timestamp::from_unix_millis(0L)
}

pub fn unrecognized_variant_default() -> UnrecognizedVariant {
	unrecognized_variant_from_bytes(0, Bytes::default())
}
