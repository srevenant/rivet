defmodule Rivet.Ecto.Collection.Update do
  import Transmogrify

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      ##########################################################################
      @spec update(@model.t, map) :: model_p_result | ecto_p_result
      def update(%@model{} = item, attrs) when is_map(attrs) do
        with {:ok, attrs} <- @model.change_prep(item, attrs) do
          item
          |> @model.changeset(attrs)
          |> @repo.update()
          |> @model.change_post(attrs)
        end
      end

      def update!(item, attrs) do
        with {:ok, out} <- update(item, attrs), do: out
      end

      ##########################################################################
      def update_all(clauses, set) when is_list(clauses),
        do: from(@model, where: ^clauses) |> @repo.update_all(set)

      def update_all(query, set), do: @repo.update_all(query, set)

      @spec update_fill(@model.t, attrs :: map) :: model_p_result | ecto_p_result
      def update_fill(%@model{} = item, attrs) do
        update(item, transmogrify(attrs, %{no_nil_value: true}))
      end

      ##########################################################################
      @spec replace(map, Keyword.t()) :: model_p_result | ecto_p_result
      def replace(attrs, clauses) do
        case one(clauses) do
          {:error, _} ->
            create(attrs)

          {:ok, item} ->
            update(item, attrs)
        end
      end

      # on update DELETE the original item, to get cascading cleanup of related
      # tables.  Can be dangerous if you aren't aware of the impact
      @spec drop_replace(map, Keyword.t()) :: model_p_result | ecto_p_result
      def drop_replace(attrs, clauses) do
        case one(clauses) do
          {:error, _} ->
            create(attrs)

          {:ok, item} ->
            with {:ok, _} <- delete(item) do
              create(attrs)
            end
        end
      end

      @doc """
      Similar to replace, but it doesn't remove existing values if the attrs has nil
      """
      @spec replace_fill(map, Keyword.t()) :: model_p_result | ecto_p_result
      def replace_fill(attrs, clauses) do
        case one(clauses) do
          {:error, _} ->
            create(attrs)

          {:ok, item} ->
            update_fill(item, attrs)
        end
      end

      @spec upsert(map) :: model_p_result | ecto_p_result
      def upsert(attrs, on_conflict \\ :nothing) do
        attrs
        |> @model.build()
        |> @repo.insert(on_conflict: on_conflict)
      end
    end
  end
end
