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

    soft_limit =
      Keyword.get(opts, :soft_limit, Application.get_env(:rivet, :search_soft_limit, 25))

    hard_limit =
      Keyword.get(opts, :hard_limit, Application.get_env(:rivet, :search_hard_limit, 400))

    quote do
      @search_soft_limit unquote(soft_limit)
      @search_hard_limit unquote(hard_limit)
      @search_spec Rivet.Search.Validate.spec(unquote(spec))
      @search_default Rivet.Search.Validate.defaults(unquote(default), @search_spec)
      @search_parent Rivet.Utils.Module.mod_parent(__MODULE__)

      def default_cols(), do: {:ok, @search_default}

      def search(%{filter: _} = args) do
        unquote(build).(args, @search_spec, @search_default)
        |> query_with_status(args)
      end

      def search(%{id}), do: @search_parent.one(id: id) |> Rivet.Search.Result.status_results()

      def query_with_status(query, args, opts \\ []) do
        Rivet.Search.query_with_status_(
          {@search_parent, @search_soft_limit, @search_hard_limit},
          query,
          args,
          opts
        )
      end
    end
  end

  import Ecto.Query
  alias Rivet.Search.Result

  ##############################################################################
  def query_with_status_(meta, {:ok, %Ecto.Query{} = query}, args, opts),
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

  ##############################################################################
  defp get_limit(%{limit: limit}, hard, soft) when is_integer(limit) do
    cond do
      limit < 0 -> soft
      limit >= hard -> hard
      true -> limit
    end
  end

  defp get_limit(_, _, soft), do: soft

  ##############################################################################
  defp get_total(_, _, total: count) when is_integer(count), do: count
  defp get_total(parent, query, _), do: parent.aggregate(query, :count)
end
