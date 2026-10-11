defmodule Rivet.Test.Search.TestTableTest do
  use Rivet.Test.Case, async: true
  alias Rivet.TestTable.Search

  test "build_query" do
    filters = [
      %{n: "status", v: ["status"], o: :a},
      %{n: "name", v: ["boop"], o: :d}
    ]

    assert {:ok,
            %{
              joins: [],
              order_bys: [_, _],
              wheres: [%{expr: {:and, _, [_, _]}}]
            }} = Search.build_filter_query(filters, [])
  end
end
