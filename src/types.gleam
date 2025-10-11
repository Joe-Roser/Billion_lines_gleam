import gleam/dict

pub type Agg {
  Agg(min: Float, max: Float, sum: Float, count: Int)
}

pub type State =
  dict.Dict(BitArray, Agg)
// vim: ts=2 sts=2 sw=2 et
