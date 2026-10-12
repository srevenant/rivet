defmodule Rivet.Ecto.Context do
  @moduledoc false
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @rivet_table_prefix Application.compile_env(:rivet, :table_prefix, "")
    end
  end
end
