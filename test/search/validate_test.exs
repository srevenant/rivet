defmodule Rivet.Test.Search.ValidateTest do
  use Rivet.Test.Case, async: true
  alias Rivet.Search.Validate

  def bogun_join3(a, _, _), do: {:ok, a}
  def bogun_join2(a, _), do: {:ok, a}

  setup do
    {:ok,
     %{
       schema:
         Validate.schema!(
           status: [type: :atom, list: :in, prep: &__MODULE__.bogun_join2/2],
           name: [type: :glob, join: &__MODULE__.bogun_join3/3],
           at: [type: :date, order: :only, join: {:at, &__MODULE__.bogun_join3/3}]
         )
     }}
  end

  test "Validate.schema" do
    [
      {"status: join must be a function/3 or {atom, function/3}",
       status: [type: :atom, join: &{&1, &2, &3, &4}]},
      {"Search schema: expected a map or keyword list", "not a list"}
    ]
    |> Enum.each(fn {msg, schema} ->
      assert_raise ArgumentError, msg, fn -> Validate.schema!(schema) end
    end)
  end

  test "Validate.defaults", %{schema} do
    assert [%{n: "name"}] = Validate.default_filters!([[n: "name"]], schema)

    [
      {"Search defaults must be a list", "not a list"},
      {"Search default: unknown column \"boop\"", [%{n: "boop"}]},
      {"Search default: unknown column \"boop\"", [[n: :boop]]},
      {"Search default #1: missing or invalid n", [[x: "bad"]]}
    ]
    |> Enum.each(fn {msg, defs} ->
      assert_raise ArgumentError, msg, fn -> Validate.default_filters!(defs, schema) end
    end)
  end

  test "Validate.options!" do
    assert [schema: []] = Validate.options!(schema: [])

    assert_raise ArgumentError, "Unknown Rivet.Search options: [:default_filter]", fn ->
      Validate.options!(schema: [], default_filter: [])
    end

    assert_raise ArgumentError, "Duplicate Rivet.Search options", fn ->
      Validate.options!(schema: [], schema: [])
    end
  end
end
