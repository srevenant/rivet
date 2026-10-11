defmodule Rivet.Test.Search.Filter.OrderTest do
  use Rivet.Test.Case, async: true
  import Ecto.Query

  alias Rivet.Search.Filter.{Order, Prep}
  alias Rivet.TestTable

  setup do
    {:ok, %{search: %Rivet.Search{}}}
  end

  describe "prep_order errors" do
    setup do
      scheme = %{name: :name, key: :name, order: fn _, _, _, _ -> {:error, :not_allowed} end}
      {:ok, %{scheme}}
    end

    test "propagates custom callback errors", %{scheme, search} do
      assert {:error, :not_allowed} = Order.prep_order(search, %{o: :asc}, scheme)
    end

    test "rejects malformed callback results", %{scheme, search} do
      scheme = %{scheme | order: fn _, _, _, _ -> :invalid end}

      assert {:error, "External order function returned invalid shape for name"} =
               Order.prep_order(search, %{o: :asc}, scheme)
    end
  end

  describe "prep_order good" do
    test "ignores order: false" do
      existing = [name: {:asc, :name}]
      search = %Rivet.Search{order: existing}
      scheme = %{name: :status, key: :status, order: false}

      assert {:ok, ^existing} = Order.prep_order(search, %{o: :desc}, scheme)
    end

    test "supports a custom order callback", %{search} do
      scheme = %{
        name: :name,
        key: :name,
        order: fn state, :desc, _, scheme ->
          {:ok, Keyword.put(state.order, scheme.name, {:desc, scheme.key})}
        end
      }

      assert {:ok, [name: {:desc, :name}]} = Order.prep_order(search, %{o: :desc}, scheme)
    end
  end

  describe "column_order" do
    test "with no ordering", %{search} do
      query = from(t in TestTable, as: :t)

      assert {:ok, ^query} = Order.column_order(query, search)
    end

    test "with a named join" do
      query = from(t in TestTable, as: :t, join: r in TestTable, as: :related, on: r.id == t.id)

      # Two-element tuples refer to the base query.
      # Three-element tuples refer to a named binding.
      search = %Rivet.Search{order: [{:asc, :name}, {:desc, :related, :name}]}

      assert {:ok,
              %Ecto.Query{
                order_bys: [%{expr: [{:asc, _}]}, %{expr: [{:desc, _}]}],
                joins: [_]
              }} = Order.column_order(query, search)
    end
  end

  test "resolve_order error" do
    assert {:error, "Invalid filter order: :sideways"} = Prep.resolve_order(:sideways, nil)
  end
end
