defmodule Rivet.Ecto.Collection.All do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      ##########################################################################
      @spec all!(keyword() | Ecto.Query.t(), list()) :: [@model.t()]
      def all!(clauses \\ [], args \\ [])

      def all!(clauses, args) when is_list(clauses) do
        from(t in @model, where: ^clauses)
        |> Rivet.Ecto.Collection.enrich_query_args(args)
        |> @repo.all()
      end

      def all!(query, args),
        do: Rivet.Ecto.Collection.enrich_query_args(query, args) |> @repo.all()

      ##########################################################################
      @spec all(keyword() | Ecto.Query.t(), list()) ::
              {:error, ecto_p_result} | {:ok, [@model.t()]}
      def all(clauses \\ [], args \\ []) do
        {:ok, all!(clauses, args)}
      rescue
        error ->
          {:error, error}
      end
    end
  end
end
