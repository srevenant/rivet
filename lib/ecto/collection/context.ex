defmodule Rivet.Ecto.Collection.Context do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      import Ecto.Changeset
      import Ecto.Query, only: [from: 2]

      @model Keyword.get(opts, :model, __MODULE__)
      @repo Application.compile_env!(:rivet, :repo)

      @type ecto_p_result() :: {:ok | :error, Ecto.Changeset.t()}
      @type model_p_result() :: {:ok, @model.t()}
    end
  end
end
