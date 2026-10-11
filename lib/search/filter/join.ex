defmodule Rivet.Search.Filter.Join do
  @moduledoc """

  Prepares and applies joins for search filters.

  Join callbacks receive `(join_key, query, state)` and must return:

    `{:ok, query, state}`
    `{:error, reason}`

  Callbacks can inspect `state.joined` to avoid duplicate joins.

  """
  alias Rivet.Search.Filter

  ##############################################################################
  # compile-time validation assures it will be only one of these three shapes
  def prep_join(joins, %{join: nil}), do: {:ok, joins}

  def prep_join(joins, %{join: {name, func}}) when is_function(func),
    do: {:ok, Map.put(joins, name, func)}

  def prep_join(joins, %{join, name}) when is_function(join),
    do: {:ok, Map.put(joins, name, join)}

  ##############################################################################
  @spec add_joins(Ecto.Query.t(), Filter.t() | nil) ::
          {:ok, Ecto.Query.t()} | {:error, term()}
  def add_joins(%Ecto.Query{} = query, %Rivet.Search{joins} = state) when map_size(joins) > 0 do
    joined = join_keys(query)
    add_joins_(query, %{state | joined}, Map.to_list(joins))
  end

  def add_joins(%Ecto.Query{} = query, _), do: {:ok, query}

  #### inner
  defp add_joins_(query, state, [{filter_key, join} | rest]) do
    # the case just assures external functions are shaped right
    case join.(filter_key, query, state) do
      {:ok, %Ecto.Query{} = query, %Rivet.Search{} = state} ->
        # merge both whatever is in the query plus the filter key
        joined = Map.put(state.joined, filter_key, :joined) |> Map.merge(join_keys(query))

        add_joins_(query, %{state | joined}, rest)

      {:error, _} = pass ->
        pass

      _other ->
        {:error, "External join function returned invalid shape for #{filter_key}"}
    end
  end

  defp add_joins_(query, _state, []), do: {:ok, query}

  defp join_keys(query) do
    query.joins
    |> Enum.reject(&is_nil(&1.as))
    |> Map.new(fn %{as: key} -> {key, :joined} end)
  end
end
