defmodule Rivet.Ecto.Collection.ShortId do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      if :short_id in Keyword.get(opts, :features, []) do
        import Rivet.Utils.Codes, only: [stripped_uuid: 1, get_shortest: 4]

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
