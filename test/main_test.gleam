import gleam/dict
import gleam/erlang/process
import gleam/io
import gleeunit
import pipeline/collator
import pipeline/processor
import types

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn single_batch_process_test() {
  let subj = process.new_subject()
  let assert Ok(proc) = processor.start(subj)

  proc.data
  |> process.send(processor.Process(<<"hello;00.0":utf8>>))

  proc.data
  |> process.send(processor.End)
  io.println("sent messages")

  let assert collator.Add(val) =
    subj
    |> process.receive_forever()

  case dict.get(val, <<"hello":utf8>>) {
    Ok(types.Agg(0.0, 0.0, 0.0, 1)) -> Nil
    _ -> panic
  }

  let assert collator.End =
    subj
    |> process.receive_forever()

  Nil
}
