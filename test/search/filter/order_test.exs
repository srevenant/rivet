defmodule Test.Rivet.Search.Filter.OrderTest do
  use Rivet.Test.Case, async: true
  alias Rivet.Search.Filter

  test "Filter.Order" do
    assert {:ok, %Ecto.Query{}} == Filter.Order.column_order(%Ecto.Query{}, %Filter.State{order: []})
  end
end
