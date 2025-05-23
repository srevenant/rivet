defmodule Rivet.Ecto.Model do
  @moduledoc """
  For data models using Ecto.

  # Options:

  * `id_type: :uuid` (default) or: :intid, :none
  * `export_json: [:field, ...]` — becomes `@derive {Jason.Encoder, [fields...]}`
  * `debug: true` — will print out some compile-time information for debugging
  """

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @rivet_debug Keyword.get(opts, :debug, false)
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

      if @rivet_debug do
        IO.inspect(
          [model: __MODULE__, opts: opts, id_type: @rivet_id_type, primary_key: @primary_key],
          label: "Rivet.Ecto.Model"
        )
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
