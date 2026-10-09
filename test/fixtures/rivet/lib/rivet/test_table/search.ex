defmodule Rivet.TestTable.Search do
  use Rivet.Search,
    spec: [
      status: [type: :atom, list: :in],
      name: [type: :glob],
      owner: [type: :glob, key: :name], # , join: &fjoin_to_owner/3],
      inserted_at: [type: :date, order: :only],
      updated_at: [type: :date, order: :only]
    ],
    default: [[n: "name"]],
    build: &__MODULE__.build_search_query/3

  # use Core.Context
  # import Rivet.Search
  # import Rivet.Search.Tools
  import Ecto.Query
  alias Rivet.TestTable

  def build_search_query(%{filters}, spec, default) do
    from(ip in TestTable, as: :t)
    |> Rivet.Search.Filter.enrich_search_query(&filter_expr/1, spec, filters, default)
  end

  ##############################################################################
  # defp filter_expr({:owner, v}), do: Db.Org.Search.filter_org_expr(:owner, v)
  # defp filter_expr({:pod, v}), do: Db.Location.Search.filter_location_expr(v)
  defp filter_expr(x), do: filter_ip_expr(x)

  defp filter_ip_expr({:status, %{x: :is, v: stat}}),
    do: {:ok, dynamic([ip: ip], ip.status in ^stat)}

  defp filter_ip_expr({:status, %{x: :no, v: stat}}),
    do: {:ok, dynamic([ip: ip], ip.status not in ^stat)}

  defp filter_ip_expr({:subnet_id, %{x: :is, v: uuid}}),
    do: {:ok, dynamic([ip: ip], ip.subnet_id == ^uuid)}

  defp filter_ip_expr({:subnet_id, %{x: :no, v: uuid}}),
    do: {:ok, dynamic([ip: ip], ip.subnet_id != ^uuid)}

  defp filter_ip_expr({:address, %{x: :is, v: addr}}),
    do: {:ok, dynamic([], fragment("CAST(address AS VARCHAR) LIKE ?", ^addr))}

  defp filter_ip_expr({:address, %{x: :no, v: addr}}),
    do: {:ok, dynamic([], fragment("CAST(address AS VARCHAR) NOT LIKE ?", ^addr))}

  defp filter_ip_expr({:notes, %{x: :is, v: note}}),
    do: {:ok, dynamic([ip: ip], ilike(ip.notes, ^note))}

  defp filter_ip_expr({:notes, %{x: :no, v: note}}),
    do: {:ok, dynamic([ip: ip], not ilike(ip.notes, ^note))}

  defp filter_ip_expr(x), do: {:error, "Unsupported filter operation: #{inspect(x)}"}
end
