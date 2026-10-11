defmodule Rivet.Test.Search.TestTableTest do
  use Rivet.Test.Case, async: true
  alias Rivet.TestTable.Search

  test "build_query" do
    args = %{
      filter: [
        %{n: "status", v: ["status"], o: :a},
        %{n: "name", v: ["boop"], o: :d}
      ]
    }

    spec = Search.search_spec!()
    defs = Search.search_default!()

    assert {:ok,
            %{
              joins: [],
              order_bys: [_, _],
              wheres: [%{expr: {:and, _, [_, _]}}]
            }} = Search.build_search_query(args, spec, defs)
  end
end
