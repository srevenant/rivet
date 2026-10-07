defmodule Rivet.Test.Case do
  use ExUnit.CaseTemplate

  using do
    quote location: :keep do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Rivet.Test.Case
      alias Ecto.Changeset
    end
  end

  setup tags do
    opts = tags |> Map.take([:isolation]) |> Enum.to_list()
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Rivet.Test.Repo, opts)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Rivet.Test.Repo, {:shared, self()})
    end

    :ok
  end

  # because I don't want it in a system folder, I'm not using system mktemp
  def temp_dir() do
    {:ok, random} = Rivet.Utils.Codes.generate(6, fn _ -> false end)
    System.tmp_dir!() |> Path.join(random)
  end
end
