defmodule Rivet.Search.Filter.Order do
  @moduledoc """

  Prepares and applies column ordering to Ecto queries.

  Custom order callbacks receive `(state, direction, filter, schema)` returning:

    `{:ok, keyword_order}`
    `{:error, reason}`

  Filter direction(asc/desc) are normalized during preparation so will be correct
  by the time this runs.

  """
  alias Rivet.Search.Filter
  import Ecto.Query
  @spec column_order(Ecto.Query.t(), Filter.State.t()) :: {:ok, Ecto.Query.t()} | {:error, term()}

  def column_order(%Ecto.Query{} = query, %Filter.State{order: []}), do: {:ok, query}

  def column_order(%Ecto.Query{} = query, %Filter.State{order: order}),
    do: build_order_by(query, order)

  ##############################################################################
  defp build_order_by(%Ecto.Query{} = query, [{ord, cname} | rest]),
    do: build_order_by(order_by(query, [], [{^ord, ^cname}]), rest)

  defp build_order_by(%Ecto.Query{} = query, [{ord, tname, cname} | rest]) do
    build_order_by(
      from([{^tname, t}] in query, order_by: [{^ord, field(t, ^cname)}]),
      rest
    )
  end

  defp build_order_by(query, []), do: {:ok, query}

  ##############################################################################

  @spec prep_order(Filter.State.t(), map(), map()) :: {:ok, keyword()} | {:error, term()}
  # no order
  def prep_order(%Filter.State{order}, _, %{order: false}), do: {:ok, order}

  # callback for order; note: compile-time verification already assured it was arity/4
  def prep_order(state, fltr, %{name, order: ord_func} = scheme) when is_function(ord_func) do
    case ord_func.(state, fltr.o, fltr, scheme) do
      {:ok, o} = pass ->
        if Keyword.keyword?(o), do: pass, else: {:error, "Invalid order result for #{name}"}

      {:error, _} = pass ->
        pass

      _other ->
        {:error, "External order function returned invalid shape for #{name}"}
    end
  end

  # other ordering scenarios; filter order is already parsed and takes precedence
  def prep_order(%Filter.State{order}, fltr, %{name, key: cname} = scheme) do
    value =
      case scheme[:join] do
        nil -> {fltr.o, cname}
        {binding, _} -> {fltr.o, binding, cname}
        _ -> {fltr.o, name, cname}
      end

    {:ok, Keyword.put(order, name, value)}
  end
end
