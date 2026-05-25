pub struct Method[T, U] {
  name : String
  number : Int
  request_serializer : Serializer[T]
  response_serializer : Serializer[U]
  doc : String
}

pub fn[T, U] Method::new(
  name : String,
  number : Int,
  request_serializer : Serializer[T],
  response_serializer : Serializer[U],
  doc : String,
) -> Method[T, U] {
  {
    name,
    number,
    request_serializer,
    response_serializer,
    doc,
  }
}