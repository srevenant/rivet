defmodule Test.Rivet.Ecto.AtomicTest do
  use Rivet.Case, async: true
  alias RivetTestLib.Yoink

  test "Rivet atomic update" do
    assert {:ok, %{id: n_id} = y} = Yoink.create(%{name: "narf"})
    assert is_binary(n_id) and byte_size(n_id) == 36

    assert {:error, {:conditions_failed, %{name: "meep"}, _}} =
             Yoink.update(y, %{name: "yoink"}, assert: %{name: "meep"})

    assert {:ok, %{name: "yoink"}} = Yoink.update(y, %{name: "yoink"}, assert: %{name: "narf"})
  end
end
