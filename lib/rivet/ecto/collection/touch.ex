defmodule Rivet.Ecto.Collection.Touch do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @doc """
      Update our updated_at but only if it hasn't changed within a minute
      (less load)
      """
      @update_min_seconds 60
      def touch(this_id) when is_binary(this_id) do
        with {:ok, this} <- one(id: this_id) do
          touch(this)
        end
      end

      def touch(%{id: this_id, updated_at: updated}) do
        now = System.system_time(:second)

        if now - DateTime.to_unix(updated, :second) > @update_min_seconds do
          from(u in @model, where: u.id == ^this_id)
          |> @repo.update_all(set: [updated_at: DateTime.from_unix!(now, :second)])
        end
      end

      # Allow for models without timestamps.
      def touch(this), do: this
    end
  end
end
