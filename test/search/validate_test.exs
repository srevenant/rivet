defmodule Rivet.Test.Search.ValidateTest do
  use Rivet.Test.Case, async: true
  alias Rivet.Search.Validate

  def bogun_join3(a, _, _), do: {:ok, a}
  def bogun_join2(a, _), do: {:ok, a}

  setup do
    {:ok,
     %{
       spec:
         Validate.spec(
           status: [type: :atom, list: :in, prep: &__MODULE__.bogun_join2/2],
           name: [type: :glob, join: &__MODULE__.bogun_join3/3],
           at: [type: :date, order: :only, join: {:at, &__MODULE__.bogun_join3/3}]
         )
     }}
  end

  test "Validate.spec" do
    [
      {"status: join must be a function/3 or {atom, function/3}",
       status: [type: :atom, join: &{&1, &2, &3, &4}]},
      {"Search spec: expected a map or keyword list", "not a list"}
    ]
    |> Enum.each(fn {msg, spec} ->
      assert_raise ArgumentError, msg, fn -> Validate.spec(spec) end
    end)
  end

  test "Validate.defaults", %{spec} do
    assert [%{n: "name"}] = Validate.defaults([[n: "name"]], spec)

    [
      {"Search defaults must be a list", "not a list"},
      {"Search default: unknown column \"boop\"", [%{n: "boop"}]},
      {"Search default: unknown column \"boop\"", [[n: :boop]]},
      {"Search default #1: missing or invalid n", [[x: "bad"]]}
    ]
    |> Enum.each(fn {msg, defs} ->
      assert_raise ArgumentError, msg, fn -> Validate.defaults(defs, spec) end
    end)
  end
end
