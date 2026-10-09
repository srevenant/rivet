defmodule Rivet.Search.Filter.Order do
  alias Rivet.Search.Filter
  import Ecto.Query

  def column_order(query, %Filter.State{order: []}), do: query

  def column_order(query, %Filter.State{order: order}), do: build_order_by(query, order)

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  def build_order_by({:error, _} = pass, _), do: pass

  def build_order_by(query, [{ord, cname} | rest]),
    do: build_order_by(order_by(query, [], [{^ord, ^cname}]), rest)

  def build_order_by(query, [{ord, tname, cname} | rest]) do
    build_order_by(
      from([{^tname, t}] in query, order_by: [{^ord, field(t, ^cname)}]),
      rest
    )
  end

  def build_order_by(query, []), do: query

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  def prep_order(%Filter.State{order: order}, _, %{order: false}), do: order

  def prep_order(state, fltr, %{order: func} = spec) when is_function(func),
    do: func.(state, filter_order(fltr[:o]), fltr, spec)

  def prep_order(%Filter.State{} = state, _, %{name: name, key: cname, order: order})
      when order in [:asc, :desc],
      do: Keyword.put(state.order, name, {order, cname})

  def prep_order(%Filter.State{order: order}, fltr, %{name: name, key: cname, join: nil}),
    do: Keyword.put(order, name, {filter_order(fltr[:o]), cname})

  def prep_order(%Filter.State{order: order}, fltr, %{name: name, key: cname}),
    do: Keyword.put(order, name, {filter_order(fltr[:o]), name, cname})

  def filter_order(:a), do: :asc
  def filter_order(:d), do: :desc
  def filter_order(nil), do: :asc
end
