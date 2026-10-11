defmodule Rivet.TestTable.Search do
  use Rivet.Search,
    spec: [
      status: [type: :atom, list: :in],
      name: [type: :glob]
    ],
    default: [[n: "name"]],
    build: &__MODULE__.build_search_query/3

  import Ecto.Query
  alias Rivet.TestTable

  def build_search_query(%{filter}, spec, default) do
    from(t in TestTable, as: :t)
    |> Rivet.Search.Filter.enrich_search_query(&filter_expr/1, spec, filter, default)
  end

  defp filter_expr({:status, %{x: :is, v: stat}}),
    do: {:ok, dynamic([t: t], t.status in ^stat)}

  defp filter_expr({:status, %{x: :no, v: stat}}),
    do: {:ok, dynamic([t: t], t.status not in ^stat)}

  defp filter_expr({:name, %{x: :is, v: name}}),
    do: {:ok, dynamic([t: t], ilike(t.name, ^name))}

  defp filter_expr({:name, %{x: :no, v: name}}),
    do: {:ok, dynamic([t: t], not ilike(t.name, ^name))}

  defp filter_expr(x), do: {:error, "Unsupported filter operation: #{inspect(x)}"}
end
