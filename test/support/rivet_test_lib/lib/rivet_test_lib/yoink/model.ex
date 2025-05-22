defmodule RivetTestLib.Yoink do
  use TypedEctoSchema
  use Rivet.Ecto.Model

  typed_schema "yoinks" do
    field(:name, :string)
    timestamps()
  end

  use Rivet.Ecto.Collection,
    required: [:name],
    atomic: [:name],
    update: [:name]
end
