defmodule Test.Rivet.GraphqlTest do
  use Rivet.Case, async: true
  import EctoEnum

  defenum(Narf, a: 10, b: 20)

  test "Rivet.Graphql" do
    assert {:ok, :a} = Rivet.Graphql.parse_enum(%{value: "a"}, Narf)
    assert :error = Rivet.Graphql.parse_enum("nope", Narf)
  end
end
