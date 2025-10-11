import gleam/erlang/process
import pipeline/collator
import pipeline/processor
import pipeline/streamer

pub fn main() -> Nil {
  let file_name = "data.txt"

  let end_subj = process.new_subject()
  let assert Ok(coll) = collator.start(end_subj)
  let assert Ok(proc) = processor.start(coll.data)
  streamer.start(proc.data, file_name)

  process.receive_forever(end_subj)

  Nil
}
//fn read_file(stream: file_stream.FileStream, count: Int) -> Nil {
//  case file_stream.read_bytes(stream, 256) {
//    Ok(chunk) -> {
//      chunk
//      |> bit_array.to_string()
//      |> result.unwrap("Error: failed to convert to utf8")
//      |> io.print()
//
//      read_file(stream, count + 1)
//    }
//    _ -> io.println("")
//  }
//}
// vim: ts=2 sts=2 sw=2 et
