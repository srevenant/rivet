defmodule Rivet.Search.Filter.Expr do
  import Ecto.Query

  @doc """

  Applies filter expressions to a query in an AND relationship (no OR support).
  Filters with `[:no_value]` are skipped.

  """
  @spec build_expr(Ecto.Query.t(), Rivet.Search.t()) :: {:ok, Ecto.Query.t()} | {:error, term()}
  def build_expr(query, %Rivet.Search{values} = f) do
    reduce_filter_expr(&and_expr/2, f, values)
    |> finish_filter_expr(query, fn q, e -> where(q, [], ^e) end)
  end

  ##############################################################################
  def reduce_filter_expr(add, %Rivet.Search{} = f, list_as_map) when is_map(list_as_map),
    do: reduce_filter_expr_(nil, add, f, Map.to_list(list_as_map) |> Enum.reverse())

  defp reduce_filter_expr_(expr, add, %Rivet.Search{} = f, [{_, %{v: [:no_value]}} | rest]),
    do: reduce_filter_expr_(expr, add, f, rest)

  defp reduce_filter_expr_(expr, add, %Rivet.Search{} = f, [{column, filter} | rest]) do
    case f.searcher.filter_expr(column, filter, f) do
      :skip -> reduce_filter_expr_(expr, add, f, rest)
      {:ok, nexpr} -> reduce_filter_expr_(add.(expr, nexpr), add, f, rest)
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
