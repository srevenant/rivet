defmodule Rivet.Test.Search.ToolsTest do
  use Rivet.Test.Case, async: true
  import Ecto.Query
  alias Rivet.Search.Tools
  alias Rivet.TestTable

  ##############################################################################
  # fixtures
  defmodule Child do
    use Ecto.Schema

    schema "tools_children" do
      belongs_to(:parent, Rivet.Test.Search.ToolsTest.Parent)
    end
  end

  defmodule Parent do
    use Ecto.Schema

    schema "tools_parents" do
      has_many(:children, Rivet.Test.Search.ToolsTest.Child)
    end
  end

  defmodule TestEnum do
    def cast("active"), do: {:ok, :active}
    def cast(_), do: :error
  end

  ##############################################################################
  test "match helpers and date filters" do
    from_at = ~N[2026-01-01 00:00:00]
    to_at = ~N[2026-12-31 23:59:59]

    query =
      TestTable
      |> Tools.match_ilike("alice", :name)
      |> Tools.match_date_after(from_at, :inserted_at)
      |> Tools.match_date_before(to_at, :inserted_at)

    assert length(query.wheres) == 3

    assert ["alice", from_at, to_at] == Enum.map(query.wheres, fn %{params: [{v, _}]} -> v end)

    [ge: :>=, gt: :>, le: :<=, lt: :<, is: :==]
    |> Enum.each(fn {search_op, ecto_op} ->
      assert {:ok, %Ecto.Query.DynamicExpr{} = expr} =
               Tools.filter_date(:t, :inserted_at, %{x: search_op, v: from_at})

      query = where(from(t in TestTable, as: :t), ^expr)
      assert [%Ecto.Query.BooleanExpr{expr: {^ecto_op, _, _}}] = query.wheres
    end)
  end

  test "association join helpers" do
    query = from(p in Parent, as: :p)
    state = %Rivet.Search{joined: %{children: []}}

    # existing join, don't do anything
    assert ^query = Tools.stateful_join_relation(query, state, :p, :children)

    # both helpers support the default left join.
    left_joined = fn x ->
      assert %Ecto.Query{joins: [%{as: :children, qual: :left}]} = x
    end

    left_joined.(Tools.join_relation(query, :p, :children))
    left_joined.(Tools.stateful_join_relation(query, %Rivet.Search{}, :p, :children))

    # Both helpers also support an explicit join type.
    right_joined = fn x ->
      assert %Ecto.Query{joins: [%{as: :children, qual: :inner}]} = x
    end

    right_joined.(Tools.join_relation(query, :p, :children, :inner))
    right_joined.(Tools.stateful_join_relation(query, %Rivet.Search{}, :p, :children, :inner))
  end

  test "enum preparation helpers" do
    assert {:ok, :any} = Tools.prep_enum_any(:no_value, nil, TestEnum)
    assert {:ok, :any} = Tools.prep_enum_any("any", nil, TestEnum)
    assert {:ok, :active} = Tools.prep_enum_any("active", nil, TestEnum)
    assert {:ok, :mine} = Tools.prep_enum_mine("mine", nil, TestEnum)
    assert {:ok, :active} = Tools.prep_enum_mine("active", nil, TestEnum)
    assert {:ok, :active} = Tools.prep_enum("active", nil, TestEnum)
    assert {:error, "Invalid TestEnum: 'bogus'"} = Tools.prep_enum("bogus", nil, TestEnum)
  end
end
