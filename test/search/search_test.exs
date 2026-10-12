defmodule Rivet.Test.Search.SearchTest do
  use Rivet.Test.Case, async: true
  import Ecto.Query
  alias __MODULE__.MockParent.TestSearch

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

    def all(%Ecto.Query{} = query) do
      send(self(), {:query_all, query})
      {:ok, [%{id: Ecto.UUID.generate()}]}
    end
  end

  defmodule MockParent.TestSearch do
    use Rivet.Search,
      schema: [name: [type: :glob]],
      default_filters: [[n: "name"]],
      soft_limit: 3,
      hard_limit: 5

    @impl Rivet.Search
    def base_query(%Rivet.Search{} = s) do
      if s.opts[:fail_base], do: {:error, :base_failed}, else: super(s)
    end

    @impl Rivet.Search
    def filter_expr(:name, %{v: "%error%"}, _), do: {:error, :filter_failed}
    def filter_expr(:name, %{v: "%skip%"}, _), do: :skip
    def filter_expr(:name, %{v: [:no_value]}, _), do: :skip

    def filter_expr(:name, %{v: name}, _),
      do: {:ok, dynamic([mock_parent: p], ilike(p.name, ^name))}
  end

  test "search execution and callback handling" do
    # Runtime soft limit and offset, without count queries.
    assert {:ok, %{success: true, results: [_]}} =
             TestSearch.search(%{filter: [], offset: 10}, %{matching: false, soft_limit: 2})

    assert_received {:query_all, %Ecto.Query{} = query}
    assert %Ecto.Query{limit: %{params: [{2, _}]}} = query
    assert %Ecto.Query{offset: nil} = query
    refute_received :matching_count
    refute_received :total_count

    # Hard limit and both count queries.
    assert {:ok, %{success: true, matching: 7, total: 12}} =
             TestSearch.search(%{filter: [], limit: 100, offset: 10}, matching: true, total: true)

    assert_received {:query_all, %Ecto.Query{} = query}
    assert %Ecto.Query{limit: %{params: [{5, _}]}} = query
    assert %Ecto.Query{offset: %{params: [{10, _}]}} = query
    assert_received :matching_count
    assert_received :total_count

    # Callback errors propagate through the query builder.
    assert {:error, :base_failed} = TestSearch.build_filter_query([], fail_base: true)

    assert {:error, :filter_failed} =
             TestSearch.build_filter_query([%{n: "name", v: ["error"]}], [])

    # A skipped expression preserves the rest of the query.
    assert {:ok, %Ecto.Query{wheres: [], order_bys: [_]}} =
             TestSearch.build_filter_query([%{n: "name", v: ["skip"]}], [])

    # Invalid public API arguments.
    assert {:error, :args} = TestSearch.search(%{filter: nil})
    assert {:error, :args} = TestSearch.search(%{})

    # Negative limit gives default
    assert {:ok, %{limit: 3}} = TestSearch.search(%{filter: [], limit: -1})
  end

  ##############################################################################
  # this doesn't add to coverage, but assures that the generated Search instance
  # also operates as expected.
  test "public search API" do
    assert %{name: %{type: :glob}} = TestSearch.get_schema()
    assert [%{n: "name"}] = TestSearch.get_default_filters()
    assert MockParent = TestSearch.get_model()
    assert 3 = TestSearch.get_soft_limit()
    assert 5 = TestSearch.get_hard_limit()

    # def query_builder(a, b, c), do: @search_builder.(a, b, c)

    # Default-only search.
    assert {:ok, %{success: true, total: 12, matching: 7, results: [_]}} =
             TestSearch.search(%{filter: []}, matching: true, total: true)

    assert_received {:query_all, %{limit: %{params: [{3, _}]}}}

    # Explicit filter and limit.
    assert {:ok, %{success: true, results: [_]}} =
             TestSearch.search(%{filter: [%{n: "name", v: ["bob"]}], limit: 1})

    assert_received {:query_all, %{limit: %{params: [{1, _}]}}}

    # Search by ID.
    uuid = Ecto.UUID.generate()
    assert {:ok, %{success: true, results: [%{id: ^uuid}]}} = TestSearch.search(%{id: uuid})

    # Invalid filter propagates to the result status.
    assert {:ok, %{success: false, reason: "Invalid column 'unknown'"}} =
             TestSearch.search(%{filter: [%{n: "unknown", v: ["bob"]}]})
  end

  test "filter_expr fallback" do
    assert {:error, "Invalid filter column data (unknown)"} =
             TestSearch.filter_expr(:unknown, %{}, %Rivet.Search{})
  end
end
