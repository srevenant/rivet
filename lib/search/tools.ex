defmodule Rivet.Search.Tools do
  @moduledoc """
  Reusable Ecto query and filter helpers for Rivet.Search applications.
  """
  import Ecto.Query

  # # coveralls-ignore-next-line
  defguard is_joined?(m, key) when is_map_key(m.joined, key)

  ##############################################################################
  @doc """

  Applies a case-insensitive LIKE filter.

  `match` must already be escaped and formatted as a SQL LIKE pattern,
  typically by the `:glob` preparation type.

  """
  def match_ilike(query, match, column),
    do: from(item in query, where: ilike(field(item, ^column), ^match))

  def match_date_after(query, begin_at, column),
    do: from(item in query, where: field(item, ^column) >= ^begin_at)

  def match_date_before(query, end_at, column),
    do: from(item in query, where: field(item, ^column) <= ^end_at)

  ##############################################################################
  @doc """

  Joins an association unless its binding is already recorded in `state.joined`.

  `model` is the existing named binding, and `join` is the association name
  and resulting binding. Defaults to a left join.

  """
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

  ##############################################################################
  @spec prep_enum(term(), term(), module()) :: {:ok, term()} | {:error, String.t()}

  def prep_enum_any(:no_value, _, _), do: {:ok, :any}
  def prep_enum_any("any", _, _), do: {:ok, :any}
  def prep_enum_any(a, b, c), do: prep_enum(a, b, c)
  def prep_enum_mine("mine", _, _), do: {:ok, :mine}
  def prep_enum_mine(a, b, c), do: prep_enum(a, b, c)

  def prep_enum(value, _scheme, enum) do
    with :error <- enum.cast(value) do
      mod = Rivet.Utils.Module.mod_basename(enum) |> inspect()
      {:error, "Invalid #{mod}: '#{value}'"}
    end
  end
end
