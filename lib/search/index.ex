defmodule Rivet.Search do
  @moduledoc """

  Search columns(filters) on tables with a dynamic ecto query builder system.

  See the [Rivet Search Guide](search/README.md) for configuration, examples,
  and GraphQL integration.

  """

  alias Rivet.Search.Filter

  @type search_filter :: %{
          required(:n) => String.t(),
          required(:o) => :asc | :desc,
          required(:x) => atom(),
          required(:v) => term()
        }
  @type search_filters :: list(search_filter())
  @type search_module :: module()

  @type user_args :: map()
  @type runtime_opts :: map()
  @type query_result :: {:ok, Ecto.Query.t()} | {:error, term()}
  @type filter_result :: {:ok, Ecto.Query.dynamic_expr()} | :skip | {:error, term()}
  @type status_map :: %{
          required(:success) => boolean(),
          optional(:message) => String.t() | nil,
          optional(:total) => non_neg_integer() | nil,
          optional(:matching) => non_neg_integer() | nil,
          optional(:search_id) => String.t() | nil,
          optional(atom()) => term()
        }

  @type status_result :: %{
          required(:success) => boolean(),
          required(:status) => status_map(),
          optional(:result) => term(),
          optional(:results) => list(),
          optional(atom()) => term()
        }

  @type search_error :: {:error, atom() | String.t()}
  @type search_result :: {:ok, status_result()} | search_error()
  @type search_opts :: keyword() | map()

  @callback search(user_args(), search_opts()) :: search_result()

  @doc """

  Builds a WHERE expression for a prepared search column.

  NOTE: Rivet.Search adds a default filter_expr that returns an error, so if
  you do not want to define one you can leave it out.

  """
  @callback filter_expr(column :: atom(), search_filter(), Rivet.Search.t()) :: filter_result()

  @doc "Creates the initial Ecto query before search filters are applied."
  @callback base_query(runtime_opts()) :: {:ok, Ecto.Query.t()} | {:error, term()}

  @doc "Applies application-specific modifications to an enriched search query."
  @callback build_filter_query(search_filters(), runtime_opts()) :: query_result()

  @optional_callbacks search: 2, base_query: 1, build_filter_query: 2

  defmacro __using__(module_opts) do
    # this is compile-time stuff so not coverage tracked -BJG
    # coveralls-ignore-start
    module_opts = Rivet.Search.Validate.options!(module_opts)

    schema = Keyword.fetch!(module_opts, :schema)
    default_filters = Keyword.get(module_opts, :default_filters, [])

    limits = Application.get_env(:rivet, :search_limit, []) |> Map.new()
    limits = Map.merge(%{soft: 25, hard: 400}, limits)
    soft_limit = Keyword.get(module_opts, :soft_limit, limits.soft)
    hard_limit = Keyword.get(module_opts, :hard_limit, limits.hard)

    model = Keyword.get(module_opts, :model)

    # coveralls-ignore-stop

    quote do
      @behaviour Rivet.Search
      @before_compile Rivet.Search

      @search_schema Rivet.Search.Validate.schema!(unquote(schema))
      @search_default Rivet.Search.Validate.default_filters!(
                        unquote(default_filters),
                        @search_schema
                      )

      @search_soft_limit unquote(soft_limit)
      @search_hard_limit unquote(hard_limit)

      @search_model unquote(model)
      @search_model if is_nil(@search_model),
                      do: Rivet.Utils.Module.mod_parent(__MODULE__),
                      else: @search_model

      @search_model_name Rivet.Utils.Module.mod_basename(@search_model, :atom)

      import Ecto.Query
      alias Rivet.Search.{Tools, Filter, Result}
      alias Rivet.Search.Tools.MixedAuth

      @doc """
      Search module configuration values
      """
      def get_schema(), do: @search_schema
      def get_default_filters(), do: @search_default
      def get_soft_limit(), do: @search_soft_limit
      def get_hard_limit(), do: @search_hard_limit
      def get_model(), do: @search_model

      @doc """
      See search/README.md
      """
      def search(filters, opts \\ nil), do: Rivet.Search.search(__MODULE__, filters, opts)

      defoverridable search: 2

      def base_query(_filter_struct), do: {:ok, from(@search_model, as: ^@search_model_name)}
      defoverridable base_query: 1

      def build_filter_query(filters, opts),
        do: Rivet.Search.build_filter_query_(__MODULE__, filters, opts)

      defoverridable build_filter_query: 2
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def filter_expr(name, _, _), do: {:error, "Invalid filter column data (#{name})"}
    end
  end

  ##############################################################################
  # state struct

  @type t :: %__MODULE__{
          order: list(),
          values: map(),
          joins: map(),
          joined: map(),
          schema: map(),
          searcher: search_module(),
          opts: map()
        }

  defstruct order: [],
            values: %{},
            joins: %{},
            joined: %{},
            schema: %{},
            searcher: nil,
            opts: %{}

  ##############################################################################
  # Utilities; largely called from the template of this module
  import Ecto.Query
  import Rivet.Guards
  alias Rivet.Search.{Result, Filter}

  @doc """

  Executes a search using the supplied search module.

  Options:
    * `:matching` - count all matching records (default: true)
    * `:total` - count all records in the underlying table (default: false)
    * `:hard_limit` - runtime override of compile-time hard_limit
    * `:soft_limit` - runtime override of compile-time soft_limit

  """
  @default_opts %{matching: true}
  def search(searcher, user_args, nil),
    do: search_(searcher, user_args, @default_opts)

  def search(searcher, user_args, opts) when is_list(opts),
    do: search_(searcher, user_args, Map.new(opts))

  def search(searcher, user_args, opts) when is_map(opts),
    do: search_(searcher, user_args, opts)

  ############
  defp search_(searcher, %{filter} = user_args, opts) when is_list(filter) do
    case searcher.build_filter_query(filter, opts) do
      {:ok, %Ecto.Query{} = query} ->
        model = searcher.get_model()
        query_limit = get_limit(searcher, user_args[:limit], opts)

        matching = get_matching(opts, model, query)
        query_offset = get_offset(opts, user_args[:offset])

        total = get_total(opts, model)

        query
        |> limit(^query_limit)
        |> add_offset(query_offset)
        |> model.all()
        |> Result.status_results(%{matching, total, offset: query_offset, limit: query_limit})

      {:error, e} ->
        Result.build_error(e)
    end
  end

  defp search_(searcher, %{id}, _opts) when is_uuid(id),
    do: searcher.get_model().one(id: id) |> Rivet.Search.Result.status_results()

  defp search_(_, _, _), do: {:error, :args}

  ##############################################################################
  defp get_limit(searcher, limit, opts) when is_integer(limit) do
    if limit < 0 do
      opts[:soft_limit] || searcher.get_soft_limit()
    else
      hard = opts[:hard_limit] || searcher.get_hard_limit()

      if limit >= hard do
        hard
      else
        limit
      end
    end
  end

  # no limit in args, default to soft
  defp get_limit(searcher, _, opts), do: opts[:soft_limit] || searcher.get_soft_limit()

  ##############################################################################
  # they want a count of all matching results (not limited)
  defp get_offset(%{matching: true}, offset) when is_integer(offset) and offset > 0, do: offset
  defp get_offset(_, _), do: nil

  # they want a count of all matching results (not limited)
  defp get_matching(%{matching: true}, model, query), do: model.aggregate(query, :count)
  defp get_matching(_, _, _), do: nil

  # they want a full-table count
  defp get_total(%{total: true}, model), do: model.aggregate(model, :count)
  defp get_total(_, _), do: nil

  ##############################################################################
  def build_filter_query_(searcher, filters, opts) when is_list(filters) do
    with {:ok, %Rivet.Search{} = state} <- Filter.Prep.prep_state(searcher, filters, opts),
         {:ok, query} <- searcher.base_query(state),
         {:ok, query} <- Filter.Join.add_joins(query, state),
         {:ok, query} <- Filter.Expr.build_expr(query, state),
         do: Filter.Order.column_order(query, state)
  end

  ##############################################################################
  defp add_offset(query, nil), do: query
  defp add_offset(query, n) when is_integer(n), do: offset(query, ^n)
end
