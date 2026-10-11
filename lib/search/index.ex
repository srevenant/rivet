defmodule Rivet.Search do
  @moduledoc """

  Typical usage pattern:

    @col_spec [
      status: [type: :atom, list: :in],
      name: [type: :glob],
      owner: [type: :glob, key: :name, join: &fjoin_to_owner/3],
      inserted_at: [type: :date, order: :only],
      updated_at: [type: :date, order: :only]
    ]

    @default [[n: "name"]]

    use Rivet.Search,
      spec: @col_spec
      default: @default,
      build: &build_search_query/4


  FILTERS
  #######

  a list of column filters are sent from the FE which determine the order plus
  any filter arguments all at once. the order of each in the list defines
  how to order the resulting columns as well.

  Column filter sent from FE are single-letter keys (to keep it smaller):

      'n' — column name  * required
      'o' — order (a, d)   a=ascending, d=descending; default is `a`
      'v' — [value,...]    Value used in filtering, as a list of strings.
                           List is required even if only one element because
                           of GraphQL only allowing for one type
      'x' — operator       one of:

            "is" equals, matching, or in a list (this is default if unspecified)
            "no" not equals, matching, or not in list
                 (note: the remaining only apply to numbers & dates)
            "lt" Less than
            "le" Less than or equal to
            "gt" Greater than
            "ge" Greater than or equal to

  Example (no quotes on keys, only for sake of example):

    [
      {n: "location", o: "a", v: ["a-location-name"]},
      {n: "serial", v: ["Q53"]},
      {n: "loc"},
      {n: "cond", v: ["failing", "servicing"], x: "no"},
      {n: "sku"}
    ]

  SPEC
  ####

  Concurrently, a column "Spec" is defined on the backend code, which is used by
  prep_filters. The spec defines how to parse the filters, and enriches a filter
  struct to be used to build the query.

  Spec is key/value map, where the key (atom) matches the name specified in the
  filter (`n:` attribute). The value is a dict specification:

      type: {type}   — see below for built-in types. You can add custom types by
                       also defining prep and order.
      list:          - (default: false), may also be :in, in which case the value
                       must be a list and 'x in y' is used as the query.
      key: :atom     — the key used to reference the data on the model. Used only
                       when it does not match the spec's parent key.
      name: <auto>   - auto generates to match the spec filter key, unless changed
      join: &func/3  — function to call to build a join if defaults are not wanted
       (or) {key, &func/3} — join function like above, but stored into an alt key
                       on the filter (when two diff filters will alter the same
                       order, like `:vlan` and `:vlan_id` — the latter can specify
                       that it is just `:vlan` order).
      prep: &func/2  - additional preparing of an arg/value beyond the built-ins
      order: false   — if false, do not include in ordering (default: true)
      order: :only   — if `:only` only use it for order, not anything else
        (or) &func/4 — if it is a function, call that to generate the order value

  Input Validation
  ################

  Input validation happens in two cycles. The type can provide a function hook
  for doing complex input validation & handling (such as with locations), or
  it can use a built-in type. The built-in types are very simple. For complex
  things, use the hooked typing.

  Built-in types:

     :string   - just take it verbatim as a string
     :glob     - trim & wrap it in % # todo: strip out dangerous things?
     :uuid     - match uuid pattern
     :atom     - turn it into an existing atom (not bespoke atom)
     :integer  — turn it into an integer
     :float    — turn it into a float
     :date     — turn it into a datetime
     :location — pass-thru when a location parse is used in pre-processing

  Schema for GraphQL should include:

  enum :filter_order do
    value(:a)
    value(:d)
  end

  enum :filter_operator do
    value(:is)
    value(:no)
    value(:lt)
    value(:le)
    value(:gt)
    value(:ge)
  end

  input_object :filter_column do
    field(:n, non_null(:string))
    field(:v, list_of(:string))
    field(:o, :filter_order)
    field(:x, :filter_operator, default_value: :is)
  end

  then it can be used simply as:

    arg(:filter, list_of(:filter_column), default_value: [])


  """

  # TODO: Make behaviors for the callbacks

  defmacro __using__(opts) do
    # this is compile-time stuff so not coverage tracked -BJG
    # coveralls-ignore-start
    spec = Keyword.fetch!(opts, :spec)
    build = Keyword.fetch!(opts, :build)
    default = Keyword.get(opts, :default, [])

    limits = [soft: 25, hard: 400]
    [{:soft, soft}, {:hard, hard}] = Application.get_env(:rivet, :search_limit, limits)

    soft_limit = Keyword.get(opts, :soft_limit, soft)
    hard_limit = Keyword.get(opts, :hard_limit, hard)

    # coveralls-ignore-stop

    quote do
      @search_soft_limit unquote(soft_limit)
      @search_hard_limit unquote(hard_limit)
      @search_spec Rivet.Search.Validate.spec(unquote(spec))
      @search_default Rivet.Search.Validate.defaults(unquote(default), @search_spec)
      @search_parent Rivet.Utils.Module.mod_parent(__MODULE__)

      def search_default!(), do: @search_default
      def search_spec!(), do: @search_spec

      def search(%{filter} = args) when is_list(filter) do
        unquote(build).(args, search_spec!(), search_default!())
        |> query_with_status(args)
      end

      def search(%{id}) when not is_nil(id),
        do: @search_parent.one(id: id) |> Rivet.Search.Result.status_results()

      def search(_), do: {:error, :args}

      def query_with_status(query, args, opts \\ []) do
        Rivet.Search.query_with_status_(
          {@search_parent, @search_soft_limit, @search_hard_limit},
          query,
          args,
          opts
        )
      end
    end
  end

  import Ecto.Query
  alias Rivet.Search.Result

  ##############################################################################
  def query_with_status_(meta, {:ok, %Ecto.Query{} = query}, args, opts),
    do: query_with_status__inner(meta, query, args, opts)

  def query_with_status_(meta, %Ecto.Query{} = query, args, opts),
    do: query_with_status__inner(meta, query, args, opts)

  def query_with_status_(_, {:error, error}, _, _), do: Result.build_error(error)

  ####
  defp query_with_status__inner({parent, soft, hard}, %Ecto.Query{} = query, args, opts) do
    {_, table} = query.from.source
    total = get_total(parent, table, opts)
    limit = get_limit(args, hard, soft)
    matching = parent.aggregate(query, :count)

    parent.all(from(i in query, limit: ^limit))
    |> Result.status_results(%{total, matching})
  end

  ##############################################################################
  defp get_limit(%{limit: limit}, hard, soft) when is_integer(limit) do
    cond do
      limit < 0 -> soft
      limit >= hard -> hard
      true -> limit
    end
  end

  defp get_limit(_, _, soft), do: soft

  ##############################################################################
  defp get_total(_, _, total: count) when is_integer(count), do: count
  defp get_total(parent, query, _), do: parent.aggregate(query, :count)
end
