defmodule Rivet.Search.Tools do
  @moduledoc """
  utils for searching DB
  """
  import Ecto.Query

  # # coveralls-ignore-next-line
  # defguard is_joined?(m, key) when is_map_key(m.joined, key)

  ##############################################################################
  def match_ilike(query, match, column),
    do: from(item in query, where: ilike(field(item, ^column), ^"%#{match}%"))

  def match_date_after(query, begin_at, column),
    do:
      from(item in query,
        where: not is_nil(field(item, ^column)) and field(item, ^column) >= ^begin_at
      )

  def match_date_before(query, end_at, column),
    do:
      from(item in query,
        where: not is_nil(field(item, ^column)) and field(item, ^column) <= ^end_at
      )

  ##############################################################################
  def stateful_join_relation(a, b, c, d, type \\ :left)

  # don't do it if it is already there
  def stateful_join_relation(query, %{joined}, _, join, _) when is_map_key(joined, join),
    do: query

  def stateful_join_relation(query, _, model, join, type),
    do: join(query, type, [{^model, t}], assoc(t, ^join), as: ^join)

  ######
  def join_relation(query, model, join, type \\ :left),
    do: join(query, type, [{^model, t}], assoc(t, ^join), as: ^join)

  ##############################################################################
  def filter_date(table, column, %{x: :ge, v: date}),
    do: {:ok, dynamic([{^table, x}], field(x, ^column) >= ^date)}

  def filter_date(table, column, %{x: :gt, v: date}),
    do: {:ok, dynamic([{^table, x}], field(x, ^column) > ^date)}

  def filter_date(table, column, %{x: :le, v: date}),
    do: {:ok, dynamic([{^table, x}], field(x, ^column) <= ^date)}

  def filter_date(table, column, %{x: :lt, v: date}),
    do: {:ok, dynamic([{^table, x}], field(x, ^column) < ^date)}

  # perhaps a truncate option to pass in? truncate to hour/day/month?
  def filter_date(table, column, %{x: :is, v: date}),
    do: {:ok, dynamic([{^table, x}], field(x, ^column) == ^date)}
end
