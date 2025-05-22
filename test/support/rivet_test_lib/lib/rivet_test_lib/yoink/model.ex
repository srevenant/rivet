defmodule RivetTestLib.Yoink do
  use TypedEctoSchema
  use Rivet.Ecto.Model

  typed_schema "yoinks" do
    field(:name, :string)
    field(:object, :string)
    timestamps()
  end

  use Rivet.Ecto.Collection,
    required: [:name],
    atomic: [:name],
    update: [:name, :object]
end
