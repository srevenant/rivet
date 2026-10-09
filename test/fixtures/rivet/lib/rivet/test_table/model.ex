defmodule Rivet.TestTable do
  use TypedEctoSchema
  use Rivet.Ecto.Model

  typed_schema "test_table" do
    field(:name, :string)
    timestamps()
  end

  use Rivet.Ecto.Collection, required: [:name], atomic: [:name], update: [:name]
end
