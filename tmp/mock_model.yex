defmodule Rivet.Test.MockModel do
  use TypedEctoSchema
  use Rivet.Ecto.Model

  typed_schema "mock_modle" do
    field(:okay, :string)
  end

  use Rivet.Ecto.Collection, required: [:okay]
end
