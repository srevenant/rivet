defmodule Rivet.Ecto.Collection.Summary do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      def latest!(claims \\ [], x \\ 1) do
        from(m in @model,
          where: ^claims,
          order_by: [desc: m.inserted_at],
          limit: ^x
        )
        |> @repo.all()
      end

      def latest(claims \\ [], x \\ 1), do: {:ok, latest!(claims, x)}

      def count_by_inserted!(since) do
        query = count_by_inserted!()
        from(m in query, where: m.inserted_at >= ^since)
      end

      def count_by_inserted!() do
        from(m in @model,
          select: [fragment("inserted_at::date"), fragment("count(*) total")],
          group_by: 1,
          order_by: 1
        )
      end

      def count_by_updated!(since) do
        query = count_by_updated!()
        from(m in query, where: m.updated_at >= ^since)
      end

      def count_by_updated!() do
        from(m in @model,
          select: [fragment("updated_at::date"), fragment("count(*) total")],
          group_by: 1,
          order_by: 1
        )
      end
    end
  end
end
