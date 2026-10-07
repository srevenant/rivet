defmodule Rivet.Guards do
  @moduledoc """

  If you are ever curious about performance checking, see benchmarks/guards.ex

  """

  defguard empty_str(x) when is_binary(x) and byte_size(x) == 0
  defguard not_empty_str(x) when is_binary(x) and byte_size(x) > 0
  defguard not_empty_list(x) when is_list(x) and x != []
  defguard not_empty_map(x) when is_map(x) and map_size(x) > 0

  ##############################################################################
  # UUID fugly

  # in broad strokes only is this a uuid
  defguard is_uuid(x) when is_binary(x) and byte_size(x) == 36

  # slightly less broad strokes, but still eh
  defguard is_uuid_shape?(x)
           when is_binary(x) and byte_size(x) == 36 and
                  binary_part(x, 8, 1) == "-" and
                  binary_part(x, 13, 2) == "-4" and
                  binary_part(x, 18, 1) == "-" and
                  binary_part(x, 23, 1) == "-"

  # used by valid_uuid? below, but maybe helpful elsewhere?
  defguard is_hex?(c) when c in ?0..?9 or c in ?A..?F or c in ?a..?f

  ##############################################################################
  # and now we get into it in detail, as a function. This cannot be a guard
  # because we cannot break out binaries this way in guards, but it is here as
  # a function because it is almost such.
  def is_uuid4?(<<
        a1,
        a2,
        a3,
        a4,
        a5,
        a6,
        a7,
        a8,
        ?-,
        b1,
        b2,
        b3,
        b4,
        ?-,
        ?4,
        c2,
        c3,
        c4,
        ?-,
        d1,
        d2,
        d3,
        d4,
        ?-,
        e1,
        e2,
        e3,
        e4,
        e5,
        e6,
        e7,
        e8,
        e9,
        e10,
        e11,
        e12
      >>)
      when d1 in [?8, ?9, ?a, ?b, ?A, ?B] and
             is_hex?(a1) and is_hex?(a2) and is_hex?(a3) and is_hex?(a4) and is_hex?(a5) and
             is_hex?(a6) and is_hex?(a7) and is_hex?(a8) and is_hex?(b1) and is_hex?(b2) and
             is_hex?(b3) and is_hex?(b4) and is_hex?(c2) and is_hex?(c3) and is_hex?(c4) and
             is_hex?(d2) and is_hex?(d3) and is_hex?(d4) and is_hex?(e1) and is_hex?(e2) and
             is_hex?(e3) and is_hex?(e4) and is_hex?(e5) and is_hex?(e6) and is_hex?(e7) and
             is_hex?(e8) and is_hex?(e9) and is_hex?(e10) and is_hex?(e11) and is_hex?(e12) do
    true
  end

  def is_uuid4?(_), do: false
end
