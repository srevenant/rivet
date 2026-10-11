defmodule Rivet.Test.Search.Filter.JoinTest do
  use Rivet.Test.Case, async: true
  alias Rivet.Search.Filter
  alias Rivet.TestTable
  import Ecto.Query

  test "prep_join" do
    func = fn _, query, state -> {:ok, query, state} end

    assert {:ok, %{}} = Filter.Join.prep_join(%{}, %{join: nil})
    assert {:ok, %{k1: ^func}} = Filter.Join.prep_join(%{}, %{name: :k1, join: func})

    assert {:ok, %{k1: ^func, k2: ^func}} =
             Filter.Join.prep_join(%{k1: func}, %{join: {:k2, func}})
  end

  defp join_helper(name, query, state) do
    # All existing named joins should be tracked.
    assert Enum.all?(query.joins, &Map.has_key?(state.joined, &1.as))

    send(self(), {:joined, name})

    query =
      case name do
        :k1 -> join(query, :inner, [t: t], j in TestTable, as: :k1, on: j.id == t.id)
        :k2 -> join(query, :inner, [t: t], j in TestTable, as: :k2, on: j.id == t.id)
      end

    {:ok, query, state}
  end

  test "add_joins" do
    query = from(t in TestTable, as: :t, join: e in TestTable, as: :existing, on: e.id == t.id)

    state = %Rivet.Search{joins: %{k1: &join_helper/3, k2: &join_helper/3}}

    assert {:ok, %Ecto.Query{} = result} = Filter.Join.add_joins(query, state)

    assert [:existing, :k1, :k2] == result.joins |> Enum.map(& &1.as) |> Enum.sort()

    assert_received {:joined, :k1}
    assert_received {:joined, :k2}
  end

  test "add_joins handles callback errors" do
    query = from(t in TestTable, as: :t)
    state = %Rivet.Search{joins: %{status: fn _, _, _ -> {:error, :narf} end}}
    assert {:error, :narf} = Filter.Join.add_joins(query, state)
    state = %Rivet.Search{joins: %{status: fn _, _, _ -> :invalid end}}

    assert {:error, "External join function returned invalid shape for status"} =
             Filter.Join.add_joins(query, state)
  end
end
