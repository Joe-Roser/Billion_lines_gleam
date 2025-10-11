import gleam/bit_array
import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/string
import pipeline/collator
import types

pub fn start(subj: process.Subject(collator.Msg)) -> actor.StartResult(_) {
  let name = process.new_name("proc")
  let self = process.named_subject(name)

  actor.new(State(0, []))
  |> actor.on_message(make_handle_msg(subj, self))
  |> actor.named(name)
  |> actor.start()
}

pub type Msg {
  Process(BitArray)
  FinishedBatch(types.State)
  End
}

pub type State {
  State(fill: Int, backlog: List(BitArray))
}

const capacity: Int = 128

fn make_handle_msg(
  pass_subj: process.Subject(_),
  self_subj: process.Subject(_),
) -> _ {
  fn(state: State, msg: Msg) -> actor.Next(_, _) {
    case msg {
      Process(batch) -> {
        //spawn Task
        case state.fill {
          x if x == capacity -> {
            actor.continue(State(capacity, [batch, ..state.backlog]))
          }
          x -> {
            spawn_processor_worker(batch, self_subj)
            actor.continue(State(..state, fill: x + 1))
          }
        }
      }
      FinishedBatch(work) -> {
        process.send(pass_subj, collator.Add(work))
        io.println("Batch Proccessed")
        actor.continue(State(..state, fill: state.fill - 1))
      }
      End -> {
        case state.fill {
          0 -> {
            process.send(pass_subj, collator.End)
            io.println("Proccessing finished")
            actor.stop()
          }
          _ -> {
            process.send(self_subj, End)
            actor.continue(state)
          }
        }
      }
    }
  }
}

fn spawn_processor_worker(work: BitArray, subj: process.Subject(_)) {
  process.spawn(fn() {
    split_lines(work, <<>>, [])
    |> list.map(split_semicolon(_, <<>>))
    |> list.map(parse_num)
    |> list.fold(dict.new(), update_dict)
    |> fn(a) { FinishedBatch(a) }
    |> process.send(subj, _)
  })
}

fn split_lines(
  to_process: BitArray,
  current: BitArray,
  acc: List(BitArray),
) -> List(BitArray) {
  case to_process {
    <<"\r\n":utf8, rest:bits>> -> {
      split_lines(rest, <<>>, [current, ..acc])
    }
    <<a:8, rest:bits>> -> {
      split_lines(rest, <<current:bits, a>>, acc)
    }
    <<>> -> {
      case current {
        <<>> -> acc
        a -> [a, ..acc]
      }
    }
    _ -> {
      io.println_error("Error: bytes misaligned")
      panic
    }
  }
}

fn split_semicolon(work: BitArray, acc: BitArray) -> #(BitArray, BitArray) {
  case work {
    <<59, rest:bits>> -> #(acc, rest)
    <<a:8, rest:bits>> -> split_semicolon(rest, <<acc:bits, a>>)
    _ -> {
      io.println_error("Error: bytes misaligned")
      panic
    }
  }
}

fn parse_num(tup: #(BitArray, BitArray)) -> #(BitArray, Float) {
  case tup.1 {
    // Positive one digit
    <<b:8, ".":utf8, c:8>> -> {
      let val: Float = get_digit(b, 1.0) +. get_digit(c, 0.1)
      #(tup.0, val)
    }
    // Negative one digit - Has to go before positive two digit to avoid congflict
    <<"-":utf8, b:8, ".":utf8, c:8>> -> {
      let val: Float = get_digit(b, 1.0) +. get_digit(c, 0.1)
      #(tup.0, -1.0 *. val)
    }
    // Positive two digit
    <<a:8, b:8, ".":utf8, c:8>> -> {
      let val: Float =
        get_digit(a, 10.0) +. get_digit(b, 1.0) +. get_digit(c, 0.1)
      #(tup.0, val)
    }
    // Negative two digit
    <<"-":utf8, a:8, b:8, ".":utf8, c:8>> -> {
      let val: Float =
        get_digit(a, 10.0) +. get_digit(b, 1.0) *. get_digit(c, 0.1)
      #(tup.0, -1.0 *. val)
    }
    _ -> {
      bit_array.to_string(tup.1)
      |> result.unwrap("")
      |> string.append("Error: number format incorrect - ", _)
      |> io.println_error()
      echo "hiu"
      panic
    }
  }
}

fn get_digit(a: Int, mult: Float) -> Float {
  case a {
    0x30 -> 0.0 *. mult
    0x31 -> 1.0 *. mult
    0x32 -> 2.0 *. mult
    0x33 -> 3.0 *. mult
    0x34 -> 4.0 *. mult
    0x35 -> 5.0 *. mult
    0x36 -> 6.0 *. mult
    0x37 -> 7.0 *. mult
    0x38 -> 8.0 *. mult
    0x39 -> 9.0 *. mult
    _ -> {
      io.println_error("Error: Number does not match format")
      panic
    }
  }
}

fn update_dict(dict: types.State, tup: #(BitArray, Float)) -> types.State {
  case dict.get(dict, tup.0) {
    Ok(agg) -> {
      types.Agg(
        float.min(agg.min, tup.1),
        float.max(agg.max, tup.1),
        agg.sum +. tup.1,
        agg.count + 1,
      )
      |> dict.insert(dict, tup.0, _)
    }
    Error(_) -> dict.insert(dict, tup.0, types.Agg(tup.1, tup.1, tup.1, 1))
  }
}
// vim: ts=2 sts=2 sw=2 et
