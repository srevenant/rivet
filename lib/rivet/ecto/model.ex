defmodule Rivet.Ecto.Model do
  @moduledoc """
  For data models using Ecto.

  # Options:

  * `id_type: :uuid` (default) or: :intid, :none
  * `export_json: [:field, ...]` — becomes `@derive {Jason.Encoder, [fields...]}`
  """

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      case Keyword.get(opts, :id_type, :uuid) do
        :uuid ->
          @rivet_id_type :uuid
          @primary_key {:id, :binary_id, autogenerate: true}
          @foreign_key_type :binary_id

        :none ->
          @rivet_id_type :none
          @primary_key false

        :intid ->
          :ok
          @rivet_id_type :intid

        x ->
          raise "Invalid Rivet id_type '#{inspect(x)}', not one of: :uuid, :intid, or :none"
      end

      if Keyword.get(opts, :export_json, []) != [] do
        @derive {Jason.Encoder, Keyword.get(opts, :export_json, [])}
      end

      @timestamps_opts [type: Keyword.get(opts, :timestamp, :utc_datetime)]

      import Ecto, only: [assoc: 2]
      import Ecto.Changeset
      use Rivet.Ecto.Context
    end
  end
end
