defmodule Rivet.Search do
  @moduledoc """

  Typical usage pattern:

    @col_spec [
      status: [type: :atom, list: :in],
      name: [type: :glob],
      owner: [type: :glob, key: :name, join: &fjoin_to_owner/3],
      inserted_at: [type: :date, order: :only],
      updated_at: [type: :date, order: :only]
    ]

    @default [[n: "name"]]

    use Rivet.Search,
      spec: @col_spec
      default: @default,
      build: &build_search_query/4

  """

  defmacro __using__(opts) do
    spec = Keyword.fetch!(opts, :spec)
    build = Keyword.fetch!(opts, :build)
    default = Keyword.get(opts, :default, [])

    quote do
      @soft_limit Application.compile_env(:rivet, :search_soft_limit, 25)
      @hard_limit Application.compile_env(:rivet, :search_hard_limit, 400)
      @search_spec Map.new(unquote(spec))
      @search_default Enum.map(unquote(default), &Map.new/1)
      @parent Rivet.Utils.Module.mod_parent(__MODULE__)

      def search(%{id}), do: @parent.one(id: id) |> Rivet.Result.status_results()
      def search(%{filter} = args) do
        unquote(build).(filter, nil, @search_spec, @search_default)
        |> query_with_status(args)
      end

      def query_with_status(a, b, opts \\ []),
        do: Rivet.Search.query_with_status_({@parent, @soft_limit, @hard_limit}, a, b, opts)
    end
  end

  alias Rivet.Search.Result
  import Ecto.Query
  import Rivet.Filter, only: [enrich_search_query: 5]

  @doc """
  Most tests are in a separate file.

  iex> query_with_status({:error, "boop"}, nil, nil)
  {:ok, %{success: false, status: %{success: false, message: "boop"}, reason: "boop"}}

  """
  def query_with_status_(meta, {:ok, query}, args, opts),
    do: query_with_status__inner(meta, query, args, opts)

  def query_with_status_(meta, %Ecto.Query{} = query, args, opts),
    do: query_with_status__inner(meta, query, args, opts)

  def query_with_status_(_, {:error, error}, _, _), do: Result.build_error(error)

  ####
  defp query_with_status__inner({parent, soft, hard}, %Ecto.Query{} = query, args, opts) do
    {_, table} = query.from.source
    total = get_total(parent, table, opts)
    limit = get_limit(args, hard, soft)
    matching = parent.aggregate(query, :count)

    parent.all(from(i in query, limit: ^limit))
    |> Result.status_results(%{total, matching})
  end

  # @doc """
  # iex> get_limit(%{limit: -23}, 25, 400)
  # 25
  # iex> get_limit(%{limit: 45}, 25, 400)
  # 45
  # iex> get_limit(nil, 25, 400)
  # 25
  # iex> get_limit(%{limit: 55.555}, 25, 400)
  # 25
  # iex> get_limit(%{limit: 500}, 25, 400)
  # 400
  # """
  defp get_limit(%{limit: limit}, hard, soft) when is_integer(limit) do
    cond do
      limit < 0 -> soft
      limit >= hard -> hard
      true -> limit
    end
  end

  defp get_limit(_, _, soft), do: soft

  # @doc """
  # iex> get_total(nil, nil, total: 42)
  # 42
  #
  # iex> insert(:org)
  # iex> x = get_total(Repo, from(Db.Org), [])
  # iex> x > 0
  # """
  defp get_total(_, _, total: count) when is_integer(count), do: count
  defp get_total(parent, query, _), do: parent.aggregate(query, :count)
end
