defmodule Rivet.Test.GraphqlTest do
  use Rivet.Test.Case, async: true
  import Rivet.Ecto.DefEnum
  import Rivet.Graphql

  defenum(Narf, a: 10, b: 20)

  test "Rivet.Graphql" do
    assert {:ok, :a} = Rivet.Graphql.parse_enum(%{value: "a"}, Narf)
    assert :error = Rivet.Graphql.parse_enum("nope", Narf)
  end

  test "build" do
    assert "name is invalid" = TestApp.Yoink.build(%{name: :nope}) |> error_string()
    assert "name is invalid" = error_string({:error, "name is invalid"})
  end
end
