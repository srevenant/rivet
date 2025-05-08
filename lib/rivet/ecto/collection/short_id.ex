defmodule Rivet.Ecto.Collection.ShortId do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      if :short_id in Keyword.get(opts, :features, []) do
        import Rivet.Utils.Codes, only: [stripped_uuid: 1, get_shortest: 4]

        @not_found Keyword.get(opts, :not_found, "Nothing found")
        ##########################################################################
        # TODO: perhaps update these models to accept changing ID
        def create_with_short_id(attrs) do
          with {:ok, this} <- create(attrs |> Map.put(:short_id, Ecto.UUID.generate())),
               {:ok, id} <-
                 get_shortest(this.id |> stripped_uuid, 5, 2, fn c -> one(short_id: c) end) do
            update(this, %{short_id: id})
          end
        end

        ##########################################################################
        # It should not trigger but curiously is.  Dialyzer claims it won't get
        # a cast error.  But... it does...  Dialyzer warning:
        #
        # The pattern can never match the type.
        #
        # Pattern:
        # {:error, %Ecto.Query.CastError{:type => :binary_id}}
        #
        # Type:
        # {:error, <<_::104>>} | {:ok, _}
        @dialyzer {:nowarn_function, find_short_id: 2}
        @spec find_short_id(String.t(), any()) :: {:ok, @model.t()} | {:error, String.t()}
        def find_short_id(id, preload \\ []) do
          with {:error, _} <- one([short_id: String.downcase(id)], preload),
               {:error, %Ecto.Query.CastError{type: :binary_id}} <- one([id: id], preload) do
            {:error, @not_found}
          end
        end
      end
    end
  end
end
