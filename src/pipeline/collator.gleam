import file_streams/file_stream
import gleam/bit_array
import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/list
import gleam/otp/actor
import types

const eq: BitArray = <<"=":utf8>>

const slash: BitArray = <<"/":utf8>>

const nl: BitArray = <<"\r\n":utf8>>

pub type Msg {
  Add(types.State)
  End
}

pub fn start(
  end_subj: process.Subject(Nil),
) -> actor.StartResult(process.Subject(Msg)) {
  dict.new()
  |> actor.new()
  |> actor.on_message(make_handle(end_subj))
  |> actor.start()
}

fn make_handle(end_subj: process.Subject(Nil)) -> fn(_, _) -> _ {
  fn(state: types.State, msg: Msg) -> actor.Next(_, _) {
    case msg {
      Add(new_data) -> {
        dict.combine(state, new_data, combine_aggs)
        |> actor.continue()
      }
      End -> {
        let assert Ok(stream) = file_stream.open_write("out.txt")

        let assert Ok(_) =
          state
          |> dict.to_list()
          |> list.map(format_entries)
          // |> list.sort()
          |> list.fold(<<>>, bit_array.append)
          |> file_stream.write_bytes(stream, _)

        let assert Ok(_) = file_stream.close(stream)

        process.send(end_subj, Nil)

        actor.stop()
      }
    }
  }
}

fn combine_aggs(a: types.Agg, b: types.Agg) -> types.Agg {
  types.Agg(
    float.min(a.min, b.min),
    float.max(a.max, b.max),
    a.sum +. b.sum,
    a.count + b.count,
  )
}

fn format_entries(tup: #(BitArray, types.Agg)) -> BitArray {
  let #(name, data) = tup
  let mean =
    data.sum /. int.to_float(data.count)
    |> float.to_precision(1)

  <<
    name:bits,
    eq:bits,
    float.to_string(data.min):utf8,
    slash:bits,
    float.to_string(mean):utf8,
    slash:bits,
    float.to_string(data.max):utf8,
    nl:bits,
  >>
}
// vim: ts=2 sts=2 sw=2 et
