defmodule Rivet.Search.Filter do
  alias Rivet.Search.Filter

  @spec enrich_search_query(Ecto.Query.t(), function(), map(), list(), list()) ::
          {:ok, Ecto.Query.t()} | {:error, term()}
  def enrich_search_query(%Ecto.Query{} = query, builder, spec, filters, deffs)
      when is_map(spec) and is_list(filters) do
    with {:ok, state} <- Filter.Prep.prep_state(spec, filters, deffs),
         {:ok, query} <- Filter.Join.add_joins(query, state),
         {:ok, query} <- Filter.Expr.build_expr(query, state, builder),
         do: Filter.Order.column_order(query, state)
  end
end
