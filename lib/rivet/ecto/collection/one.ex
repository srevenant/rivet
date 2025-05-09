defmodule Rivet.Ecto.Collection.One do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      ##########################################################################
      if Keyword.get(opts, :id_type, :uuid) == :uuid do
        @type id :: Ecto.UUID.t()
      else
        @type id :: integer
      end

      if Keyword.get(opts, :not_found, :string) == :atom do
        # map is Ecto.Query.CastError, but that has no type
        @type one_error :: {:error, atom() | map()}
        @not_found :not_found
      else
        @type one_error :: {:error, String.t() | map()}
        @not_found "Nothing found"
      end

      ##########################################################################
      @spec one!(id | keyword() | Ecto.Query.t(), preload :: list()) :: nil | @model.t()
      def one!(x, preload \\ [])

      if Keyword.get(opts, :id_type, :uuid) == :uuid do
        def one!(id, preload) when is_binary(id), do: inner_one!([id: id], preload)
      else
        def one!(id, preload) when is_integer(id), do: inner_one!([id: id], preload)
      end

      def one!(other, preload), do: inner_one!(other, preload)

      defp inner_one!(clauses, preload) when is_list(clauses) do
        @repo.one!(from(@model, where: ^clauses, preload: ^preload))
      rescue
        err -> {:error, err}
      end

      defp inner_one!(query, preload) do
        @repo.one!(from(query, preload: ^preload))
      rescue
        err -> {:error, err}
      end

      ##########################################################################
      @spec one(id | keyword() | Ecto.Query.t(), preload :: list()) :: {:ok, @model.t()} | one_error
      def one(x, preload \\ [])

      if Keyword.get(opts, :id_type, :uuid) == :uuid do
        def one(id, preload) when is_binary(id), do: inner_one([id: id], preload)
      else
        def one(id, preload) when is_integer(id), do: inner_one([id: id], preload)
      end

      def one(other, preload), do: inner_one(other, preload)

      defp inner_one(clauses, preload) when is_list(clauses) do
        case @repo.one(from(@model, where: ^clauses, preload: ^preload)) do
          nil -> {:error, @not_found}
          result -> {:ok, result}
        end
      rescue
        err -> {:error, err}
      end

      defp inner_one(query, preload) do
        case @repo.one(from(query, preload: ^preload)) do
          nil -> {:error, @not_found}
          result -> {:ok, result}
        end
      rescue
        err -> {:error, err}
      end
    end
  end
end
