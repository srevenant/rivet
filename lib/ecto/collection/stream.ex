defmodule Rivet.Ecto.Collection.Stream do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      def stream_all!(args, func) do
        stream = stream(args, [])

        @repo.transaction(fn ->
          stream
          |> Stream.each(func)
          |> Stream.run()
        end)
      end

      def stream(clauses, args)

      def stream(clauses, args) when is_list(clauses),
        do: from(t in @model, where: ^clauses) |> stream(args)

      def stream(query, args),
        do: Rivet.Ecto.Collection.enrich_query_args(query, args) |> @repo.stream()
    end
  end
end
