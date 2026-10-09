defmodule Rivet.Test.Ecto.AtomicTest do
  use Rivet.Test.Case, async: true

  test "Rivet atomic update" do
    assert {:ok, %{id: n_id} = y} = Rivet.TestTable.create(%{name: "narf"})
    assert is_binary(n_id) and byte_size(n_id) == 36

    assert {:error, {:conditions_failed, %{name: "meep"}, _}} =
             Rivet.TestTable.update(y, %{name: "yoink"}, assert: %{name: "meep"})

    assert {:ok, %{name: "yoink"}} =
             Rivet.TestTable.update(y, %{name: "yoink"}, assert: %{name: "narf"})
  end
end
