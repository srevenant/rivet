defmodule Rivet.Test.Search.Filter.PrepTest do
  use Rivet.Test.Case, async: true
  alias Rivet.Search.{Filter, Validate}
  alias Rivet.Search.Filter.{State, Order}
  import Filter.Prep, only: [prep_state: 3]

  setup do
    {:ok, start: DateTime.utc_now()}
  end

  test "prep_state" do
    assert {:error, "Bad search scheme?" <> _} =
             prep_state(%{a: %{type: :boop}}, [%{n: "a", v: ["asdf"]}], [])

    assert {:error, "Invalid column 'a'" <> _} =
             prep_state(%{z: %{type: :boop}}, [%{n: "a", v: ["asdf"]}], [])

    assert {:error, "Invalid search filter value: \"asdf\""} =
             prep_state(%{a: %{type: :string}}, [%{n: "a", v: "asdf"}], [])

    assert {:error, "Invalid search filter value: [\"valid\", 42]"} =
             prep_state(%{a: %{type: :string}}, [%{n: "a", v: ["valid", 42]}], [])

    assert {:ok, :asc} = Filter.Prep.resolve_order(nil, nil)

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

    schema = %{
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
      %{n: "k4", o: :d, v: [" bork%"]},
      %{n: "k1", v: [""]},
      %{n: "k5", v: [uuid]},
      %{n: "k6", v: ["30.0"]},
      %{n: "k7", v: ["2025-05-08T17:34:15.113668Z"]}
    ]

    # check default w/no filters at all
    # assert {:ok, %{order: [_]}} = prep_state(schema, [], [%{n: "k3", o: :asc}])

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
                k2: %{v: 10, x: :is, n: "k2", o: :desc},
                k3: %{v: "narf", x: :no, n: "k3", o: :asc},
                k4: %{v: "%bork\\%%", x: :is, n: "k4", o: :desc},
                k5: %{v: ^uuid, x: :is, n: "k5", o: :asc},
                k6: %{v: 30.0, x: :is, n: "k6", o: :asc},
                k7: %{v: ~U[2025-05-08 17:34:15.113668Z], x: :is, n: "k7", o: :asc}
              }
            }} = prep_state(schema, filters, [])

    assert {:error, "Invalid value for k5: not a uuid"} =
             prep_state(schema, [%{n: "k5", v: ["bad"]}], [])

    assert {:ok, %{values: %{k4: %{v: [:no_value]}}}} =
             prep_state(schema, [%{n: "k4", v: ["   "]}], [])

    assert {:error, "Invalid search filter: missing column name"} =
             prep_state(schema, [%{}], [])
  end

  test "prep_state defaults and custom prep", %{start} do
    valid_prep2 = fn value, %{name} -> {:ok, "#{name}:#{value}"} end
    valid_prep3 = fn value, %{name}, %{meta} -> {:ok, "#{meta.prefix}:#{name}:#{value}"} end

    schema =
      [
        k1: [type: :string, list: :in, order: false],
        k2: [prep: valid_prep2, order: false],
        k3: [prep: valid_prep3, order: false],
        k4: [type: :date, order: :desc]
      ]
      |> Validate.schema!()

    filter =
      [
        [n: "k1", v: []],
        [n: "k2", v: ["alpha"]],
        [n: "k3", v: ["beta"]],
        [n: "k4", v: ["now"]]
      ]
      |> Validate.default_filters!(schema)

    assert {:ok,
            %Filter.State{
              order: [{:desc, :k4}],
              values: %{
                k1: %{v: [:no_value]},
                k2: %{v: "k2:alpha"},
                k3: %{v: "test:k3:beta"},
                k4: %{v: now}
              }
            }} = Filter.Prep.prep_state(schema, filter, [], %{prefix: "test"})

    whence = DateTime.utc_now()

    assert DateTime.compare(now, start) in [:eq, :gt]
    assert DateTime.compare(now, whence) in [:eq, :lt]
  end

  test "prep_state atom and integer validation" do
    schema = [status: [type: :atom], count: [type: :integer]] |> Validate.schema!()

    assert {:ok,
            %Filter.State{
              values: %{
                status: %{v: :active},
                count: %{v: 42}
              }
            }} =
             prep_state(
               schema,
               [
                 %{n: "status", v: ["active"]},
                 %{n: "count", v: ["42"]}
               ],
               []
             )

    # Random string ensures it isn't an existing atom.
    bad_atom = "unknown_#{Ecto.UUID.generate()}"
    bad_err = "Invalid value for status: #{inspect(bad_atom)}"

    assert {:error, ^bad_err} = prep_state(schema, [%{n: "status", v: [bad_atom]}], [])

    assert {:error, "Invalid value for count: (int) \"narf\""} =
             prep_state(schema, [%{n: "count", v: ["narf"]}], [])
  end

  test "prep callback returning no_value" do
    prep = fn _ -> {:ok, :no_value} end

    schema = Validate.schema!(scalar: [prep: prep], listed: [list: :in, prep: prep])

    filters = [%{n: "scalar", v: ["anything"]}, %{n: "listed", v: ["anything"]}]

    assert {:ok, %State{values: %{scalar: %{v: [:no_value]}, listed: %{v: [:no_value]}}}} =
             prep_state(schema, filters, [])
  end

  test "prep_order uses named join binding" do
    join_func = fn _, query, state -> {:ok, query, state} end

    schema = %{name: :owner_name, key: :name, join: {:owner, join_func}, order: nil}

    assert {:ok, [owner_name: {:desc, :owner, :name}]} =
             Order.prep_order(%State{}, %{o: :desc}, schema)
  end

  test "prep callback skips individual filters" do
    schema =
      Validate.schema!(ignored: [type: :string, prep: fn _ -> :skip end], name: [type: :string])

    filters = [%{n: "ignored", v: ["anything"]}, %{n: "name", v: ["Bob"]}]

    assert {:ok, %Filter.State{values: %{name: %{v: "Bob"}}, order: [{:asc, :name}]}} =
             prep_state(schema, filters, [])
  end
end
