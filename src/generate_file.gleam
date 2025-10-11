import file_streams/file_stream
import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list
import gleam/string

pub fn main() -> Nil {
  let assert Ok(stream) = file_stream.open_write("data.txt")

  let assert Ok(Nil) =
    list.range(1, 10)
    |> list.map(fn(i) { i % 3 })
    |> list.map(int.to_string)
    |> list.map(fn(s) { s <> ";0" <> s <> ".0" })
    |> string.join("\r\n")
    |> bit_array.from_string()
    |> file_stream.write_bytes(stream, _)

  io.println("content generated")

  let assert Ok(Nil) = file_stream.close(stream)

  io.println("file written")

  Nil
}
// vim: ts=2 sts=2 sw=2 et
