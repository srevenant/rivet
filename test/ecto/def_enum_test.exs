defmodule Rivet.Test.Ecto.DefEnumTest do
  use ExUnit.Case, async: true
  alias Rivet.Ecto.DefEnum

  describe "validate_enum!/1" do
    test "accepts a valid keyword-style pair list" do
      assert :ok = DefEnum.validate_enum!(a: 1, b: 2)
    end

    test "accepts a valid tuple list" do
      assert :ok = DefEnum.validate_enum!([{:a, 1}, {:b, 2}])
    end

    test "accepts module keys after normalization" do
      assert :ok = DefEnum.validate_enum!([{String, 1}, {Integer, 2}])
    end

    test "raises for an invalid list entry" do
      assert_raise ArgumentError, ~r/2-tuples|not a tuple/, fn ->
        DefEnum.validate_enum!([1, 2, 3])
      end
    end

    test "raises when values are not integers" do
      assert_raise ArgumentError, ~r/defenum values must be integers/, fn ->
        DefEnum.validate_enum!(a: "1")
      end
    end

    test "raises when keys are duplicated" do
      assert_raise ArgumentError, ~r/defenum keys must be unique/, fn ->
        DefEnum.validate_enum!(a: 1, a: 2)
      end
    end
  end

  describe "typespec_ast/1" do
    test "empty enum" do
      assert DefEnum.typespec_ast([]) == quote(do: none())
    end

    test "single atom key enum" do
      assert DefEnum.typespec_ast([:a]) == :a
    end

    test "single module key enum" do
      assert DefEnum.typespec_ast([String]) == String
    end

    test "multiple key enum" do
      assert DefEnum.typespec_ast([:a, :b, :c]) ==
               {:|, [], [{:|, [], [:a, :b]}, :c]}
    end

    test "multiple module keys enum" do
      assert DefEnum.typespec_ast([String, Integer]) ==
               {:|, [], [String, Integer]}
    end
  end

  ##############################################################################
  defp assert_enum(mod, expected_values, expected_map) do
    assert mod.values() == expected_values
    assert mod.enum_map() == expected_map
    assert mod.type() == :integer
  end

  defp assert_status_enum(mod),
    do: assert_enum(mod, [:active, :disabled], %{active: 1, disabled: 2})

  defp compile_enum(holder, name, enum_ast) do
    holder_mod = Module.concat(__MODULE__, holder)
    enum_mod = Module.concat(holder_mod, name)

    Code.compile_quoted(
      quote do
        defmodule unquote(holder_mod) do
          require DefEnum
          alias Core.Db.Ident.User

          DefEnum.defenum(unquote(enum_mod), unquote(enum_ast))
        end
      end
    )

    enum_mod
  end

  ##############################################################################
  test "defenum defines enum module from keyword input" do
    compile_enum(:KeywordHolder, :Status, quote(do: [active: 1, disabled: 2]))
    |> assert_status_enum()
  end

  test "defenum defines enum module from tuple-list input" do
    compile_enum(:TupleHolder, :Status, quote(do: [{:active, 1}, {:disabled, 2}]))
    |> assert_status_enum()
  end

  test "defenum defines enum module from map input" do
    compile_enum(:MapHolder, :Status, quote(do: %{active: 1, disabled: 2}))
    |> assert_status_enum()
  end

  alias Core.Db.Ident.User

  test "defenum supports aliased module keys in tuple-list input" do
    compile_enum(:AliasTupleHolder, :Type, quote(do: [{User, 10}]))
    |> assert_enum([Core.Db.Ident.User], %{Core.Db.Ident.User => 10})
  end

  test "defenum supports aliased module keys in map input" do
    compile_enum(:AliasMapHolder, :Type, quote(do: %{User => 10}))
    |> assert_enum([Core.Db.Ident.User], %{Core.Db.Ident.User => 10})
  end
end
