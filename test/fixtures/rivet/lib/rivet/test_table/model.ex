defmodule Rivet.TestTable do
  use TypedEctoSchema
  use Rivet.Ecto.Model
  import Rivet.Ecto.DefEnum

  defenum(Status, none: 1, name: 2)

  typed_schema "test_table" do
    field(:name, :string)
    field(:status, :integer)
    timestamps()
  end

  use Rivet.Ecto.Collection, required: [:name], atomic: [:name], update: [:name, :status]
end
