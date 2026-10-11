defmodule Rivet.Test.Search.Filter.OrderTest do
  use Rivet.Test.Case, async: true
  import Ecto.Query

  alias Rivet.Search.Filter.{Order, Prep}
  alias Rivet.TestTable

  test "column_order with no ordering" do
    query = from(t in TestTable, as: :t)

    assert {:ok, ^query} = Order.column_order(query, %Rivet.Search{})
  end

  test "column_order with a named join" do
    query = from(t in TestTable, as: :t, join: r in TestTable, as: :related, on: r.id == t.id)

    # Two-element tuples refer to the base query.
    # Three-element tuples refer to a named binding.
    state = %Rivet.Search{order: [{:asc, :name}, {:desc, :related, :name}]}

    assert {:ok,
            %Ecto.Query{
              order_bys: [%{expr: [{:asc, _}]}, %{expr: [{:desc, _}]}],
              joins: [_]
            }} = Order.column_order(query, state)
  end

  test "prep_order ignores order: false" do
    existing = [name: {:asc, :name}]
    state = %Rivet.Search{order: existing}
    schema = %{name: :status, key: :status, order: false}

    assert {:ok, ^existing} = Order.prep_order(state, %{o: :desc}, schema)
  end

  test "prep_order supports fixed directions" do
    state = %Rivet.Search{}

    # Fixed descending overrides the frontend's ascending request.
    schema = %{name: :name, key: :name, order: :desc}
    assert {:ok, [name: {:asc, :name}]} = Order.prep_order(state, %{o: :asc}, schema)
    schema = %{schema | order: :asc}
    assert {:ok, [name: {:desc, :name}]} = Order.prep_order(state, %{o: :desc}, schema)
  end

  test "prep_order supports a custom order callback" do
    schema = %{
      name: :name,
      key: :name,
      order: fn state, :desc, _, schema ->
        {:ok, Keyword.put(state.order, schema.name, {:desc, schema.key})}
      end
    }

    assert {:ok, [name: {:desc, :name}]} = Order.prep_order(%Rivet.Search{}, %{o: :desc}, schema)
  end

  test "prep_order propagates custom callback errors" do
    schema = %{name: :name, key: :name, order: fn _, _, _, _ -> {:error, :not_allowed} end}
    assert {:error, :not_allowed} = Order.prep_order(%Rivet.Search{}, %{o: :asc}, schema)
  end

  test "prep_order rejects malformed callback results" do
    schema = %{name: :name, key: :name, order: fn _, _, _, _ -> :invalid end}

    assert {:error, "External order function returned invalid shape for name"} =
             Order.prep_order(%Rivet.Search{}, %{o: :asc}, schema)
  end

  test "coverage" do
    assert {:error, "Invalid filter order: :sideways"} = Prep.resolve_order(:sideways, nil)
  end
end
