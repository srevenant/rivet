defmodule Rivet.Test.Search.SearchTest do
  use Rivet.Test.Case, async: true
  import Ecto.Query

  doctest Rivet.Search.Tools, import: true
  doctest Rivet.Search.Result, import: true

  ##############################################################################
  # fixtures
  defmodule MockParent do
    use TypedEctoSchema
    use Rivet.Ecto.Model

    # double-tapping this, yikes. but we shouldn't hit it.
    typed_schema "test_table" do
      field(:name, :string)
      field(:status, :integer)
      timestamps()
    end

    # with some mock overrides
    def one(id: id), do: {:ok, %{id: id}}

    def aggregate(__MODULE__, :count) do
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
      schema: [name: [type: :glob]],
      default_filters: [[n: "name"]],
      soft_limit: 3,
      hard_limit: 5

    @impl Rivet.Search
    def filter_expr(:name, %{v: [:no_value]}), do: :skip
    def filter_expr(:name, %{v: name}), do: {:ok, dynamic([mock_parent: p], ilike(p.name, ^name))}
  end

  # ##############################################################################
  # test "query_with_status counts, limits and results" do
  #   meta = {MockParent, 3, 5}
  #   query = from(t in TestTable, as: :t)
  #
  #   # Explicit total skips the unfiltered aggregate.
  #   assert {:ok, %{success: true, total: 88, matching: 7, results: [%{id: 1}]}} =
  #            Rivet.Search.search(
  #            meta, {:ok, query}, %{limit: 2}, total: 88)
  #
  #   refute_received :total_count
  #   assert_received :matching_count
  #   assert_received {:limit, [{2, _}]}
  #
  #   # Default, negative, invalid, zero, normal, and hard-capped limits.
  #   [
  #     {%{}, 3},
  #     {%{limit: -1}, 3},
  #     {%{limit: "bad"}, 3},
  #     {%{limit: 0}, 0},
  #     {%{limit: 2}, 2},
  #     {%{limit: 5}, 5},
  #     {%{limit: 100}, 5}
  #   ]
  #   |> Enum.each(fn {args, expected} ->
  #     assert {:ok, %{success: true, total: 12, matching: 7, results: [%{id: 1}]}} =
  #              Rivet.Search.query_with_status_(meta, query, args, [])
  #
  #     assert_received :total_count
  #     assert_received :matching_count
  #     assert_received {:limit, [{^expected, _}]}
  #   end)
  # end

  ##############################################################################
  # this doesn't add to coverage, but assures that the generated Search instance
  # also operates as expected.
  test "public search API" do
    alias MockParent.Search, as: TestSearch

    assert %{name: %{type: :glob}} = TestSearch.get_schema()
    assert [%{n: "name"}] = TestSearch.get_default_filters()
    assert MockParent = TestSearch.get_model()
    assert 3 = TestSearch.get_soft_limit()
    assert 5 = TestSearch.get_hard_limit()

    # def query_builder(a, b, c), do: @search_builder.(a, b, c)

    # Default-only search.
    assert {:ok, %{success: true, total: 12, matching: 7, results: [_]}} =
             TestSearch.search(%{filter: []}, matching: true, total: true)

    assert_received {:limit, [{3, _}]}

    # Explicit filter and limit.
    assert {:ok, %{success: true, results: [_]}} =
             TestSearch.search(%{filter: [%{n: "name", v: ["bob"]}], limit: 1})

    assert_received {:limit, [{1, _}]}

    # Search by ID.
    uuid = Ecto.UUID.generate()
    assert {:ok, %{success: true, results: [%{id: ^uuid}]}} = TestSearch.search(%{id: uuid})

    # Invalid filter propagates to the result status.
    assert {:ok, %{success: false, reason: "Invalid column 'unknown'"}} =
             TestSearch.search(%{filter: [%{n: "unknown", v: ["bob"]}]})
  end
end
