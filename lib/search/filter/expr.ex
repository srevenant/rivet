defmodule Rivet.Search.Filter.Expr do
  alias Rivet.Search.Filter
  import Ecto.Query

  @doc """

  Applies filter expressions to a query in an AND relationship (no OR support).
  Filters with `[:no_value]` are skipped.

  """
  @spec build_expr(Ecto.Query.t(), Filter.State.t(), atom()) ::
          {:ok, Ecto.Query.t()} | {:error, term()}
  def build_expr(query, %Filter.State{values: values}, searcher) when is_atom(searcher) do
    reduce_filter_expr(&and_expr/2, searcher, values)
    |> finish_filter_expr(query, fn q, e -> where(q, [], ^e) end)
  end

  ##############################################################################
  def reduce_filter_expr(add, searcher, list_as_map) when is_map(list_as_map),
    do: reduce_filter_expr_(nil, add, searcher, Map.to_list(list_as_map) |> Enum.reverse())

  ####### inner
  defp reduce_filter_expr_(expr, add, searcher, [{_, %{v: [:no_value]}} | rest]),
    do: reduce_filter_expr_(expr, add, searcher, rest)

  defp reduce_filter_expr_(expr, add, searcher, [{column, filter} | rest]) do
    case searcher.filter_expr(column, filter) do
      :skip -> reduce_filter_expr_(expr, add, searcher, rest)
      {:ok, nexpr} -> reduce_filter_expr_(add.(expr, nexpr), add, searcher, rest)
      {:error, _} = error -> error
    end
  end

  defp reduce_filter_expr_(nil, _, _, []), do: :skip
  defp reduce_filter_expr_(expr, _, _, []), do: {:ok, expr}

  ##############################################################################
  defp finish_filter_expr(:skip, query, _finisher), do: {:ok, query}
  defp finish_filter_expr({:ok, expr}, query, finisher), do: {:ok, finisher.(query, expr)}
  defp finish_filter_expr({:error, _} = error, _, _), do: error

  def and_expr(nil, e), do: e
  def and_expr(expr, e), do: dynamic([], ^expr and ^e)
end

### Keep around for a bit incase we ever want to do an 'or' option
# def build_or_expr({:error, _} = error, _, _), do: error
#
# def build_or_expr(query, searcher, %{excludes: excludes}) do
#   reduce_filter_expr(&or_expr/2, searcher, excludes)
#   |> finish_filter_expr(query, fn q, e ->
#     e = dynamic([], not (^e))
#     where(q, [], ^e)
#   end)
# end
# def or_expr(nil, e), do: e
# def or_expr(expr, e), do: dynamic([], ^expr or ^e)
