defmodule Rivet.Test.Search.Filter.PrepTest do
  use Rivet.Test.Case, async: true

  defmodule TestSearch do
    def no_join(a, _, _), do: a
    def prep_no_value(_), do: {:ok, :no_value}
    def prep_skip(_), do: :skip
    def named_join(_, query, state), do: {:ok, query, state}

    use Rivet.Search,
      model: Rivet.TestTable,
      schema: [
        g: [type: :glob, key: :gx],
        s: [type: :string],
        f: [type: :float],
        d: [type: :date],
        a: [type: :atom],
        u: [type: :uuid],
        i: [type: :integer, join: &__MODULE__.no_join/3, key: :ix],
        o: [type: :string, order: :only],
        no_value: [prep: &__MODULE__.prep_no_value/1],
        no_value_list: [list: :in, prep: &__MODULE__.prep_no_value/1],
        named_join: [type: :string, join: {:alt_name, &__MODULE__.named_join/3}],
        skipped: [type: :string, prep: &__MODULE__.prep_skip/1]
      ],
      # default_filters: [[n: "g"]],
      soft_limit: 3,
      hard_limit: 5

    def test(filters, opts \\ %{}), do: Filter.Prep.prep_state(__MODULE__, filters, opts)
  end

  setup do
    {:ok, start: DateTime.utc_now(), uuid: Ecto.UUID.generate()}
  end

  ##############################################################################
  test "prep_state errors", %{uuid} do
    [
      {%{n: "z"}, ~r"Invalid column 'z'"},
      {%{n: "g", v: "asdf"}, ~r{Invalid search filter value: "asdf"}},
      {%{n: "g", v: ["valid", 42]}, ~r{Invalid search filter value: \["valid", 42\]}},
      {%{n: "f", v: ["no"]}, ~r{Invalid value for f: \(float\) "no"}},
      {%{n: "i", v: ["no"]}, ~r{Invalid value for f: \(int\) "no"}},
      {%{n: "d", v: ["no"]}, ~r{Invalid ISO8601 Date for d: invalid_format}},
      {%{n: "s", v: ["no", "yes"]}, ~r"Invalid values for filter column 's'"},
      {%{n: "a", v: ["very bad % borken #{uuid}"]}, ~r"Invalid value for a: "},
      {%{n: "u", v: ["bad"]}, ~r"Invalid value for u: not a uuid"},
      {%{}, ~r"Invalid search filter: missing column name"}
    ]
    |> Enum.each(fn {f, err_rx} ->
      # a little goofy but it helps us see the RX in play
      assert {^err_rx, {:error, msg}} = {err_rx, TestSearch.test([f])}
      assert msg =~ err_rx
    end)
  end

  ##############################################################################
  test "prep_state good types", %{uuid} do
    filters = [
      %{n: "a", v: ["a"], o: :a},
      # second a overrides first (bad data submitted)
      %{n: "a", v: ["    "], o: :d},
      %{n: "d", v: [now]},
      %{n: "d", v: ["2025-05-08T17:34:15.113668Z"]},
      %{n: "f", v: ["30.0"]},
      %{n: "g", o: :d, v: [" bork%"]},
      %{n: "i", o: :d, v: ["10"]},
      %{n: "s", o: :a, v: ["narf"], x: :no},
      %{n: "u", v: [uuid]},
      %{n: "o"},
      %{n: "no_value", v: ["narf"]},
      %{n: "no_value_list", v: ["narf"]},
      %{n: "named_join", o: :d},
      %{n: "prep_skip", v: ["narf"]}
    ]

    assert {:ok,
            %Rivet.Search{
              order: [
                {:desc, :a},
                {:asc, :d},
                {:asc, :f},
                {:desc, :gx},
                {:desc, :i, :ix},
                {:asc, :s},
                {:asc, :u},
                {:asc, :no_value},
                {:asc, :no_value_list},
                {:desc, :alt_name, :named_join}
              ],
              values:
                %{
                  a: %{v: [:no_value]},
                  d: %{v: ~U[2025-05-08 17:34:15.113668Z], x: :is, n: "d", o: :asc},
                  f: %{v: 30.0, x: :is, n: "f", o: :asc},
                  g: %{v: "%bork\\%%", x: :is, n: "g", o: :desc},
                  i: %{v: 10, x: :is, n: "i", o: :desc},
                  s: %{v: "narf", x: :no, n: "s", o: :asc},
                  u: %{v: ^uuid, x: :is, n: "u", o: :asc},
                  no_value: %{v: [:no_value]},
                  no_value_list: %{v: [:no_value]}
                } = values
            }} = TestSearch.test(filters)

    refute is_map_key(values, :skipped)
  end

  # test "prep_state defaults and custom prep", %{start} do
  #   valid_prep2 = fn value, %{name} -> {:ok, "#{name}:#{value}"} end
  #   valid_prep3 = fn value, %{name}, %{meta} -> {:ok, "#{meta.prefix}:#{name}:#{value}"} end
  #
  #   schema =
  #     [
  #       a: [type: :string, list: :in, order: false],
##WANT  #       i: [prep: valid_prep2, order: false],
##WANT  #       s: [prep: valid_prep3, order: false],
  #       g: [type: :date, order: :desc]
  #     ]
  #     |> Validate.schema!()
  #
  #   filter =
  #     [
  #       [n: "a", v: []],
  #       [n: "i", v: ["alpha"]],
  #       [n: "s", v: ["beta"]],
  #       [n: "g", v: ["now"]]
  #     ]
  #     |> Validate.default_filters!(schema)
  #
  #   assert {:ok,
  #           %Rivet.Search{
  #             order: [{:desc, :g}],
  #             values: %{
  #               a: %{v: [:no_value]},
  #               i: %{v: "i:alpha"},
  #               s: %{v: "test:s:beta"},
  #               g: %{v: now}
  #             }
  #           }} = Filter.Prep.prep_state(schema, filter, [], %{prefix: "test"})
  #
  #   whence = DateTime.utc_now()
  #
  #   assert DateTime.compare(now, start) in [:eq, :gt]
  #   assert DateTime.compare(now, whence) in [:eq, :lt]
  # end

  # test "prep_state atom and integer validation" do
  #   schema = [status: [type: :atom], count: [type: :integer]] |> Validate.schema!()
  #
  #   assert {:ok,
  #           %Rivet.Search{
  #             values: %{
  #               status: %{v: :active},
  #               count: %{v: 42}
  #             }
  #           }} =
  #            prep_state(
  #              schema,
  #              [
  #                %{n: "status", v: ["active"]},
  #                %{n: "count", v: ["42"]}
  #              ],
  #              []
  #            )
  #
  #   # Random string ensures it isn't an existing atom.
  #   bad_atom = "unknown_#{Ecto.UUID.generate()}"
  #   bad_err = "Invalid value for status: #{inspect(bad_atom)}"
  #
  #   assert {:error, ^bad_err} = prep_state(schema, [%{n: "status", v: [bad_atom]}])
  #
  #   assert {:error, "Invalid value for count: (int) \"narf\""} =
  #            prep_state(schema, [%{n: "count", v: ["narf"]}])
  # end
end
