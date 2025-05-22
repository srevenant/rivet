defmodule Test.Rivet.Ecto.AtomicTest do
  use Rivet.Case, async: true
  alias RivetTestLib.Yoink

  test "Rivet atomic update" do
    assert {:ok, %{id: n_id} = y} = Yoink.create(%{name: "narf", object: "brain"})
    assert is_binary(n_id) and byte_size(n_id) == 36

    # Correctly fails bad assertions.
    assert {:error, {:conditions_failed, %{name: "meep"}, _}} =
             Yoink.update(y, %{name: "yoink"}, assert: %{name: "meep"})

    # Passes good assertions
    assert {:ok, %{name: "yoink"} = y} = Yoink.update(y, %{name: "yoink"}, assert: %{name: "narf"})

    # Accepts and ignores non-atomic assertions.
    assert {:ok, %{name: "yoink", object: "cage"} = y} = Yoink.update(y, %{object: "cage"}, assert: %{object: "bogus"})

    # Updates non-atomic fields with
    # assertions.
    assert {:ok, %{name: "yoink", object: "cereal"}} = Yoink.update(y, %{object: "cereal"}, assert: %{name: "yoink"})

    # Does not update non-atomic fields
    # with bad assertions.
    assert {:error, {:conditions_failed, %{name: "meep"}, _}} =
      Yoink.update(y, %{object: "cube"}, assert: %{name: "meep"})
  end
end
