defmodule Rivet.Test.Search.Filter.PrepTest do
  use Rivet.Test.Case, async: true

  defmodule TestSearch do
    def no_join(a, _, _), do: a
    def prep_no_value(_), do: {:ok, :no_value}
    def prep_skip(_), do: :skip
    def valid_prep2(value, %{name}), do: {:ok, "#{name}:#{value}"}
    def valid_prep3(value, %{name}, %{opts}), do: {:ok, "#{opts.prefix}:#{name}:#{value}"}

    def named_join(_, query, state), do: {:ok, query, state}

    use Rivet.Search,
      model: Rivet.TestTable,
      schema: [
        a: [type: :atom],
        d1: [type: :date, order: :asc],
        d2: [type: :date],
        f: [type: :float],
        g: [type: :glob, key: :gx],
        i: [type: :integer, join: &__MODULE__.no_join/3, key: :ix],
        o: [type: :string, order: :only],
        s: [type: :string],
        u: [type: :uuid],
        no_value: [prep: &__MODULE__.prep_no_value/1],
        no_value_list: [list: :in, prep: &__MODULE__.prep_no_value/1],
        named_join: [type: :string, join: {:alt_name, &__MODULE__.named_join/3}],
        skipped: [type: :string, prep: &__MODULE__.prep_skip/1],
        vp2: [type: :string, prep: &__MODULE__.valid_prep2/2, order: false],
        vp3: [type: :string, prep: &__MODULE__.valid_prep3/3, order: false]
      ],
      soft_limit: 3,
      hard_limit: 5

    def test(filters, opts \\ %{}), do: Filter.Prep.prep_state(__MODULE__, filters, opts)
  end

  setup do
    {:ok, uuid: Ecto.UUID.generate()}
  end

  ##############################################################################
  test "prep_state errors", %{uuid} do
    bad_atom = "very bad % borken #{uuid}"

    [
      {%{n: bad_atom}, ~r"Invalid column 'very bad"},
      {%{n: "g", v: "asdf"}, ~r{Invalid search filter value: "asdf"}},
      {%{n: "g", v: ["valid", 42]}, ~r{Invalid search filter value: \["valid", 42\]}},
      {%{n: "f", v: ["no"]}, ~r{Invalid value for f: \(float\) "no"}},
      {%{n: "i", v: ["no"]}, ~r{Invalid value for i: \(int\) "no"}},
      {%{n: "d1", v: ["no"]}, ~r{Invalid ISO8601 Date for d1: invalid_format}},
      {%{n: "s", v: ["no", "yes"]}, ~r"Invalid values for filter column 's'"},
      {%{n: "a", v: [bad_atom]}, ~r{Invalid value for a: "very bad}},
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
    start = DateTime.utc_now()

    filters = [
      %{n: "a", v: ["a"], o: :a},
      # second a overrides first (bad data submitted)
      %{n: "a", v: ["    "], o: :d},
      %{n: "d1", v: ["now"]},
      %{n: "d2", v: ["2025-05-08T17:34:15.113668Z"]},
      %{n: "f", v: ["30.0"]},
      %{n: "g", o: :d, v: [" bork%"]},
      %{n: "i", o: :d, v: ["10"]},
      %{n: "o"},
      %{n: "s", o: :a, v: ["narf"], x: :no},
      %{n: "u", v: [uuid]},
      %{n: "no_value", v: ["narf"]},
      %{n: "no_value_list", v: ["narf"]},
      %{n: "named_join", o: :d},
      %{n: "skipped", v: ["narf"]},
      %{n: "vp2", v: ["alpha"]},
      %{n: "vp3", v: ["beta"]}
    ]

    assert {:ok,
            %Rivet.Search{
              order: [
                {:desc, :a},
                {:asc, :d1},
                {:asc, :d2},
                {:asc, :f},
                {:desc, :gx},
                {:desc, :i, :ix},
                {:asc, :o},
                {:asc, :s},
                {:asc, :u},
                {:asc, :no_value},
                {:asc, :no_value_list},
                {:desc, :alt_name, :named_join}
              ],
              values:
                %{
                  a: %{v: [:no_value]},
                  d1: %{v: d1},
                  d2: %{v: ~U[2025-05-08 17:34:15.113668Z]},
                  f: %{v: 30.0, x: :is, n: "f", o: :asc},
                  g: %{v: "%bork\\%%", x: :is, n: "g", o: :desc},
                  i: %{v: 10, x: :is, n: "i", o: :desc},
                  s: %{v: "narf", x: :no, n: "s", o: :asc},
                  u: %{v: ^uuid, x: :is, n: "u", o: :asc},
                  no_value: %{v: [:no_value]},
                  no_value_list: %{v: [:no_value]},
                  vp2: %{v: "vp2:alpha"},
                  vp3: %{v: "bork:vp3:beta"}
                } = values
            }} = TestSearch.test(filters, %{prefix: "bork"})

    assert DateTime.compare(d1, start) in [:eq, :gt]
    assert DateTime.compare(d1, DateTime.utc_now()) in [:eq, :lt]

    refute is_map_key(values, :skipped)
  end
end
