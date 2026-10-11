defmodule Rivet.Test.Search.Filter.OrderTest do
  use Rivet.Test.Case, async: true
  import Ecto.Query

  alias Rivet.Search.Filter.{Order, State, Prep}
  alias Rivet.TestTable

  test "column_order with no ordering" do
    query = from(t in TestTable, as: :t)

    assert {:ok, ^query} = Order.column_order(query, %State{})
  end

  test "column_order with a named join" do
    query = from(t in TestTable, as: :t, join: r in TestTable, as: :related, on: r.id == t.id)

    # Two-element tuples refer to the base query.
    # Three-element tuples refer to a named binding.
    state = %State{order: [{:asc, :name}, {:desc, :related, :name}]}

    assert {:ok,
            %Ecto.Query{
              order_bys: [%{expr: [{:asc, _}]}, %{expr: [{:desc, _}]}],
              joins: [_]
            }} = Order.column_order(query, state)
  end

  test "prep_order ignores order: false" do
    existing = [name: {:asc, :name}]
    state = %State{order: existing}
    spec = %{name: :status, key: :status, order: false}

    assert {:ok, ^existing} = Order.prep_order(state, %{o: :desc}, spec)
  end

  test "prep_order supports fixed directions" do
    state = %State{}

    # Fixed descending overrides the frontend's ascending request.
    spec = %{name: :name, key: :name, order: :desc}
    assert {:ok, [name: {:asc, :name}]} = Order.prep_order(state, %{o: :asc}, spec)
    spec = %{spec | order: :asc}
    assert {:ok, [name: {:desc, :name}]} = Order.prep_order(state, %{o: :desc}, spec)
  end

  test "prep_order supports a custom order callback" do
    spec = %{
      name: :name,
      key: :name,
      order: fn state, :desc, _, spec ->
        {:ok, Keyword.put(state.order, spec.name, {:desc, spec.key})}
      end
    }

    assert {:ok, [name: {:desc, :name}]} = Order.prep_order(%State{}, %{o: :desc}, spec)
  end

  test "prep_order propagates custom callback errors" do
    spec = %{name: :name, key: :name, order: fn _, _, _, _ -> {:error, :not_allowed} end}
    assert {:error, :not_allowed} = Order.prep_order(%State{}, %{o: :asc}, spec)
  end

  test "prep_order rejects malformed callback results" do
    spec = %{name: :name, key: :name, order: fn _, _, _, _ -> :invalid end}

    assert {:error, "External order function returned invalid shape for name"} =
             Order.prep_order(%State{}, %{o: :asc}, spec)
  end

  test "coverage" do
    assert {:error, "Invalid filter order: :sideways"} = Prep.resolve_order(:sideways, nil)
  end
end
