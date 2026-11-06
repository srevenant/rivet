defmodule Rivet.Test.Ecto.DefAppEnumTest do
  use ExUnit.Case, async: true
  import Rivet.Ecto.DefAppEnum

  def_app_enum(Status, app: :rivet, key: :test_config_enum)

  setup do
    Application.put_env(:rivet, :test_config_enum, active: 1, disabled: 2)
    assert :ok = Status.init()
    :ok
  end

  test "initializes and converts enum values" do
    assert {:ok, :active} = Status.cast(:active)
    assert {:ok, :active} = Status.cast("active")
    assert {:ok, 1} = Status.dump(:active)
    assert {:ok, :disabled} = Status.load(2)

    assert {:error, [validation: :inclusion, enum: ["active", "disabled"]]} = Status.cast(:unknown)
    assert :error = Status.dump(:unknown)
    assert :error = Status.load(99)
  end

  test "rejects invalid configuration" do
    Application.put_env(:rivet, :test_config_enum, active: "invalid")

    assert_raise ArgumentError, ~r/defenum values must be integers/, fn ->
      Status.init()
    end
  end
end
