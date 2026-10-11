defmodule Rivet.Test.Search.SearchTest do
  use Rivet.Test.Case, async: true
  import Ecto.Query
  alias Rivet.TestTable

  doctest Rivet.Search.Tools, import: true
  doctest Rivet.Search.Result, import: true

  ##############################################################################
  # fixtures
  defmodule MockParent do
    def one(id: id), do: {:ok, %{id: id}}

    def aggregate(Rivet.TestTable, :count) do
      send(self(), :total_count)
      12
    end

    def aggregate(%Ecto.Query{}, :count) do
      send(self(), :matching_count)
      7
    end

    def all(query) do
      send(self(), {:limit, query.limit.params})
      {:ok, [%{id: 1}]}
    end
  end

  defmodule MockParent.Search do
    use Rivet.Search,
      spec: [name: [type: :glob]],
      default: [[n: "name"]],
      build: &__MODULE__.build_search_query/3,
      soft_limit: 3,
      hard_limit: 5

    import Ecto.Query

    def build_search_query(%{filter}, spec, defaults) do
      from(t in Rivet.TestTable, as: :t)
      |> Rivet.Search.Filter.enrich_search_query(&filter_expr/1, spec, filter, defaults)
    end

    defp filter_expr({:name, %{v: [:no_value]}}), do: :skip

    defp filter_expr({:name, %{v: name}}),
      do: {:ok, dynamic([t: t], ilike(t.name, ^name))}
  end

  ##############################################################################
  test "query_with_status counts, limits and results" do
    meta = {MockParent, 3, 5}
    query = from(t in TestTable, as: :t)

    # Explicit total skips the unfiltered aggregate.
    assert {:ok, %{success: true, total: 88, matching: 7, results: [%{id: 1}]}} =
             Rivet.Search.query_with_status_(meta, {:ok, query}, %{limit: 2}, total: 88)

    refute_received :total_count
    assert_received :matching_count
    assert_received {:limit, [{2, _}]}

    # Default, negative, invalid, zero, normal, and hard-capped limits.
    [
      {%{}, 3},
      {%{limit: -1}, 3},
      {%{limit: "bad"}, 3},
      {%{limit: 0}, 0},
      {%{limit: 2}, 2},
      {%{limit: 5}, 5},
      {%{limit: 100}, 5}
    ]
    |> Enum.each(fn {args, expected} ->
      assert {:ok, %{success: true, total: 12, matching: 7, results: [%{id: 1}]}} =
               Rivet.Search.query_with_status_(meta, query, args, [])

      assert_received :total_count
      assert_received :matching_count
      assert_received {:limit, [{^expected, _}]}
    end)
  end

  ##############################################################################
  # this doesn't add to coverage, but assures that the generated Search instance
  # also operates as expected.
  test "public search API" do
    alias MockParent.Search, as: TestSearch

    assert %{name: %{type: :glob}} = TestSearch.search_spec!()
    assert [%{n: "name"}] = TestSearch.search_default!()

    # Default-only search.
    assert {:ok, %{success: true, total: 12, matching: 7, results: [_]}} =
             TestSearch.search(%{filter: []})

    assert_received {:limit, [{3, _}]}

    # Explicit filter and limit.
    assert {:ok, %{success: true, results: [_]}} =
             TestSearch.search(%{filter: [%{n: "name", v: ["bob"]}], limit: 1})

    assert_received {:limit, [{1, _}]}

    # Search by ID.
    assert {:ok, %{success: true, results: [%{id: 42}]}} = TestSearch.search(%{id: 42})

    # Invalid filter propagates to the result status.
    assert {:ok, %{success: false, reason: "Invalid column 'unknown' — not in spec"}} =
             TestSearch.search(%{filter: [%{n: "unknown", v: ["bob"]}]})
  end
end
