defmodule Test.Rivet.Search.Filter.PrepTest do
  use Rivet.Test.Case, async: true
  alias Rivet.Search.Filter
  import Filter.Prep, only: [prep_state: 3]

  test "prep_state" do
    assert {:error, "Bad item spec?" <> _} =
             prep_state(%{a: %{type: :boop}}, [%{n: "a", v: ["asdf"]}], [])

    assert {:error, "Invalid column 'a'" <> _} =
             prep_state(%{z: %{type: :boop}}, [%{n: "a", v: ["asdf"]}], [])

    assert {:error, "Invalid search filter param value (not a list?) \"asdf\""} =
             prep_state(%{a: %{type: :string}}, [%{n: "a", v: "asdf"}], [])

    # only ordering, no value
    # assert {:ok, %Filter.State{order: [asc: :a]}} =
    #          prep_state(%{a: %{type: :string, list: :in}}, [%{n: "a"}], [])
    #
    # assert {:ok, %Filter.State{order: [desc: :a]}} =
    #          prep_state(%{a: %{type: :string}}, [%{n: "a", o: :d}], [])

    assert {:ok, :asc} = Filter.Order.filter_order(nil)

    assert {:error, "Invalid value for a: (float) \"no\""} =
             prep_state(%{a: %{type: :float}}, [%{n: "a", v: ["no"]}], [])

    assert {:error, "Invalid ISO8601 Date for a: invalid_format"} =
             prep_state(%{a: %{type: :date}}, [%{n: "a", v: ["no"]}], [])

    assert {:error, "Invalid values for filter column 'a'"} =
             prep_state(%{a: %{type: :string}}, [%{n: "a", v: ["no", "yes"]}], [])

    assert {:error, "Invalid column 'very bad" <> _} =
             prep_state(
               %{k: %{type: :atom}},
               [
                 %{n: "very bad % borken " <> Ecto.UUID.generate()}
               ],
               []
             )

    col_spec = %{
      k1: %{order: :only},
      k2: %{type: :integer, join: & &1, colname: :bc},
      k3: %{type: :string},
      k4: %{type: :glob, colname: :x},
      k5: %{type: :uuid},
      k6: %{type: :float},
      k7: %{type: :date}
    }

    uuid = Ecto.UUID.generate()

    filters = [
      %{n: "k1"},
      %{n: "k2", o: :d, v: ["10"]},
      %{n: "k3", o: :a, v: ["narf"], x: :no},
      %{n: "k4", o: :d, v: ["bork"]},
      %{n: "k1", v: [""]},
      %{n: "k5", v: [uuid]},
      %{n: "k6", v: ["30.0"]},
      %{n: "k7", v: ["2025-05-08T17:34:15.113668Z"]}
    ]

    # check default w/no filters at all
    # assert {:ok, %{order: [_]}} = prep_state(col_spec, [], [%{n: "k3", o: :a}])

    assert {:ok,
            %Filter.State{
              order: [
                {:desc, :k2, :k2},
                {:asc, :k3},
                {:desc, :k4},
                {:asc, :k1},
                {:asc, :k5},
                {:asc, :k6},
                {:asc, :k7}
              ],
              values: %{
                k2: %{v: 10, x: :is, n: "k2", o: :d},
                k3: %{v: "narf", x: :no, n: "k3", o: :a},
                k4: %{v: "%bork%", x: :is, n: "k4", o: :d},
                k5: %{v: ^uuid, x: :is, n: "k5", o: :a},
                k6: %{v: 30.0, x: :is, n: "k6", o: :a},
                k7: %{v: ~U[2025-05-08 17:34:15.113668Z], x: :is, n: "k7", o: :a}
              }
            }} = prep_state(col_spec, filters, [])

    assert {:error, "Invalid value for k5: not a uuid"} =
             prep_state(col_spec, [%{n: "k5", v: ["bad"]}], [])
  end
end
