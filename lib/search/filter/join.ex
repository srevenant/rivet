defmodule Rivet.Search.Filter.Join do
  alias Rivet.Search.Filter

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  def prep_join(joins, %{join: nil}), do: joins

  def prep_join(joins, %{join: {name, func}}) when is_function(func),
    do: Map.put(joins, name, func)

  def prep_join(joins, %{join: func, name: name}) when is_function(func),
    do: Map.put(joins, name, func)

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  def add_joins(query, %Filter.State{joins: joins} = state) when map_size(joins) > 0,
    do: add_joins_(query, %{state | joined: join_keys(query)}, Map.to_list(joins))

  def add_joins(query, _), do: query

  ####
  @true_value []
  defp add_joins_(query, state, [{filter_key, join} | rest]) do
    with {:ok, query, state} <- join.(filter_key, query, state) do
      state = update_joins(state, filter_key, query)
      add_joins_(query, state, rest)
    end
  end

  # this is if the add_join hook sends back an error tuple, so a rare/edge case
  # that we don't even have anywhere in-code at this time.
  # defp add_joins_({:error, _} = pass, _), do: pass
  defp add_joins_(query, _state, []), do: query

  # merge both whatever is in the query plus the filter key
  defp update_joins(state, filter_key, query) do
    %{
      state
      | joined: state.joined |> Map.put(filter_key, @true_value) |> Map.merge(join_keys(query))
    }
  end

  defp join_keys(query), do: Map.new(query.joins, fn %{as: key} -> {key, @true_value} end)
end
