defmodule Rivet.TestTable.Search do
  use Rivet.Search,
    schema: [
      status: [type: :atom, list: :in],
      name: [type: :glob]
    ],
    default_filters: [[n: "name"]]

  @impl Rivet.Search
  def filter_expr(:status, %{x: :is, v: stat}, _),
    do: {:ok, dynamic([test_table: t], t.status in ^stat)}

  def filter_expr(:status, %{x: :no, v: stat}, _),
    do: {:ok, dynamic([test_table: t], t.status not in ^stat)}

  def filter_expr(:name, %{x: :is, v: name}, _),
    do: {:ok, dynamic([test_table: t], ilike(t.name, ^name))}

  def filter_expr(:name, %{x: :no, v: name}, _),
    do: {:ok, dynamic([test_table: t], not ilike(t.name, ^name))}
end
