defmodule Test.Rivet.Search.SearchTest do
  use Rivet.Test.Case, async: true
  alias Rivet.TestTable.Search

  doctest Rivet.Search.Tools, import: true
  doctest Rivet.Search.Result, import: true

  test "misc coverage" do
    assert {:ok, %{success: false, status: %{success: false, message: "boop"}, reason: "boop"}} =
             Search.query_with_status({:error, "boop"}, nil, nil)
  end
end
