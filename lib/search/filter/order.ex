defmodule Rivet.Search.Filter.Order do
  alias Rivet.Search.Filter
  import Ecto.Query

  def column_order(%Ecto.Query{} = query, %Filter.State{order: []}), do: {:ok, query}

  def column_order(%Ecto.Query{} = query, %Filter.State{order: order}), do: build_order_by(query, order)

  ##############################################################################
  def build_order_by(%Ecto.Query{} = query, [{ord, cname} | rest]),
    do: build_order_by(order_by(query, [], [{^ord, ^cname}]), rest)

  def build_order_by(%Ecto.Query{} = query, [{ord, tname, cname} | rest]) do
    build_order_by(
      from([{^tname, t}] in query, order_by: [{^ord, field(t, ^cname)}]),
      rest
    )
  end

  def build_order_by(query, []), do: {:ok, query}

  ##############################################################################
  def prep_order(%Filter.State{order}, _, %{order: false}), do: {:ok, order}

  def prep_order(state, fltr, %{order} = spec) when is_function(order) do
    # the case just assures external functions are shaped right
    case order.(state, filter_order(fltr[:o]), fltr, spec) do
      {:ok, _} = pass -> pass
      {:error, _} = pass -> pass
      _other -> {:error, "external order function returned invalid shape for #{spec.name}"}
    end
  end

  def prep_order(%Filter.State{} = state, _, %{name, order, key: cname})
      when order in [:asc, :desc],
      do: {:ok, Keyword.put(state.order, name, {order, cname})}

  def prep_order(%Filter.State{order}, fltr, %{name, key: cname, join: nil}) do
    with {:ok, o} <- filter_order(fltr[:o]), do: {:ok, Keyword.put(order, name, {o, cname})}
  end

  def prep_order(%Filter.State{order}, fltr, %{name, key: cname}) do
    with {:ok, o} <- filter_order(fltr[:o]), do: {:ok, Keyword.put(order, name, {o, name, cname})}
  end

  def filter_order(:a), do: {:ok, :asc}
  def filter_order(:d), do: {:ok, :desc}
  def filter_order(nil), do: {:ok, :asc}
  def filter_order(x), do: {:error, "invalid filter order: #{inspect(x)}"}
end
