import file_streams/file_stream
import file_streams/file_stream_error
import gleam/bit_array
import gleam/erlang/process
import gleam/io
import pipeline/processor

const read_size: Int = 1024

pub fn start(subj: process.Subject(processor.Msg), file_name: String) -> Nil {
  process.spawn(fn() {
    let assert Ok(stream) = file_stream.open_read(file_name)
    io.println("Streamer built")
    run_read(stream, <<>>, subj)
  })

  Nil
}

fn run_read(
  stream: file_stream.FileStream,
  last_end: BitArray,
  subj: process.Subject(processor.Msg),
) {
  case file_stream.read_bytes(stream, read_size) {
    Ok(data) -> {
      let #(first, last) = trim_final_line(data)
      process.send(subj, processor.Process(<<last_end:bits, first:bits>>))
      run_read(stream, last, subj)
    }
    Error(file_stream_error.Eof) -> {
      case last_end {
        <<>> -> Nil
        a -> process.send(subj, processor.Process(a))
      }
      process.send(subj, processor.End)
      io.println("Reading finished")
    }
    Error(_) -> {
      io.println_error("Error: failed to read text")
      panic
    }
  }
}

fn trim_final_line(data: BitArray) -> #(BitArray, BitArray) {
  let len = bit_array.byte_size(data)
  case find_final_line_idx(data, len) {
    -1 -> #(data, <<>>)
    i if i == len - 1 -> {
      let assert Ok(first) = bit_array.slice(data, 0, i - 1)
      #(first, <<>>)
    }
    i -> {
      let assert Ok(first) = bit_array.slice(data, 0, i - 1)
      let assert Ok(last) = bit_array.slice(data, i + 1, len - i - 1)

      #(first, last)
    }
  }
}

fn find_final_line_idx(data: BitArray, idx: Int) -> Int {
  case idx {
    0 -> -1
    n ->
      case bit_array.slice(data, n, -2) {
        Ok(<<"\r\n":utf8>>) -> {
          idx - 1
        }
        Ok(a) -> {
          echo a
          find_final_line_idx(data, idx - 1)
        }
        _ -> panic
      }
  }
}
// vim: ts=2 sts=2 sw=2 et
