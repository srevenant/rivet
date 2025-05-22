defmodule Rivet.Ecto.Collection.Update do
  import Transmogrify

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      ##########################################################################
      # can be false, or a list of fields
      @rivet_atomic Keyword.get(opts, :atomic, false)
      if @rivet_atomic == false do
        @spec update(@model.t, map() | list()) :: model_p_result | ecto_p_result
      else
        @spec update(@model.t | map(), map() | [assert: map()]) ::
                model_p_result | ecto_p_result
      end

      def update(%@model{} = item, attrs) when is_map(attrs) do
        with {:ok, attrs} <- change_prep(item, attrs) do
          item
          |> changeset(attrs)
          |> @repo.update()
          |> change_post(attrs)
        end
      end

      ##########################################################################

      if @rivet_atomic != false do
        def update(%{id: id} = changes, assert: assert) do
          with {:ok, item} <- one(id), do: update(item, changes, assert)
        end

        @spec update(@model.t, map(), assert: atomic_assert :: map()) ::
                model_p_result | ecto_p_result

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        def update(%__MODULE__{} = item, %{} = changes, assert: assert) do
          case changeset(item, changes) do
            # nothing to change...
            %{valid?: true, changes: x} when map_size(x) == 0 ->
              {:ok, item}

            %{valid?: true, changes: changes} = chgset ->
              case Map.take(assert, @rivet_atomic) do
                asserting when map_size(asserting) == 0 ->
                  # just use normal update
                  @repo.update(chgset)

                asserting ->
                  # variant of normal update
                  with {:ok, changes} <- change_prep(item, changes) do
                    id = item.id

                    from(s in __MODULE__, select: s, where: s.id == ^id)
                    |> atomic_add_asserts(Map.to_list(asserting))
                    |> atomic_run_update(id, changes, assert, Map.get(item, :updated_at))
                    |> @model.change_post(changes)
                  end
              end

            {:error, _} ->
              {:error, {:conditions_failed, assert, item}}
          end
        end

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        defp atomic_run_update({:error, _} = pass, _, _, _), do: pass

        defp atomic_run_update(query, id, changes, assert, updated_at) do
          # needs to be configurable
          changes = atomic_add_updated_at(changes, updated_at) |> Map.to_list()

          case @repo.update_all(query, set: changes) do
            {1, [item]} ->
              {:ok, item}

            {x, _} when x > 1 ->
              {:error, {:too_many, x}}

            {0, []} ->
              {:error, {:conditions_failed, assert, one!(id: id)}}
          end
        end

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        defp atomic_add_asserts(query, [{key, value} | rest]) do
          from(s in query, where: field(s, ^key) == ^value)
          |> atomic_add_asserts(rest)
        end

        defp atomic_add_asserts(query, []), do: query

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        defp atomic_add_updated_at(changes, nil), do: changes

        defp atomic_add_updated_at(changes, _),
          do: Map.put(changes, :updated_at, DateTime.utc_now())
      end

      ##########################################################################
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
      def replace(attrs, []), do: create(attrs)

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
