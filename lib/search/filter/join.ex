defmodule Rivet.Search.Filter.Join do
  alias Rivet.Search.Filter

  ##############################################################################
  # compile-time validation assures it will be only one of these three shapes
  def prep_join(joins, %{join: nil}), do: {:ok, joins}

  def prep_join(joins, %{join: {name, func}}) when is_function(func),
    do: {:ok, Map.put(joins, name, func)}

  def prep_join(joins, %{join, name}) when is_function(join),
    do: {:ok, Map.put(joins, name, join)}

  ##############################################################################
  def add_joins(%Ecto.Query{} = query, %Filter.State{joins} = state) when map_size(joins) > 0 do
    joined = join_keys(query)
    add_joins_(query, %{state | joined}, Map.to_list(joins))
  end

  def add_joins(%Ecto.Query{} = query, _), do: {:ok, query}

  #### inner
  @true_value []
  defp add_joins_(query, state, [{filter_key, join} | rest]) do
    # the case just assures external functions are shaped right
    case join.(filter_key, query, state) do
      {:ok, %Ecto.Query{} = query, state} ->
        # merge both whatever is in the query plus the filter key
        joined = Map.put(state.joined, filter_key, @true_value) |> Map.merge(join_keys(query))

        add_joins_(query, %{state | joined}, rest)

      {:error, _} = pass ->
        pass

      _other ->
        {:error, "external join function returned invalid shape for #{filter_key}"}
    end
  end

  defp add_joins_(query, _state, []), do: {:ok, query}

  defp join_keys(query), do: Map.new(query.joins, fn %{as: key} -> {key, @true_value} end)
end
