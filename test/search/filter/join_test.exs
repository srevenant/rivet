defmodule Test.Rivet.Search.Filter.JoinTest do
  use Rivet.Test.Case, async: true
  alias Rivet.Search.Filter

  test "Filter.Join" do
    assert {:ok, %Ecto.Query{}} = Filter.Join.add_joins(%Ecto.Query{}, nil)
  end
end
