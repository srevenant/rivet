defmodule Rivet.Search.Filter do
  @doc """
  # TODO: Make behaviors for the callbacks

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

  """

  alias Rivet.Search.Filter
  alias __MODULE__

  def enrich_search_query(%Ecto.Query{} = query, builder, spec, filters, deffs)
      when is_map(spec) and is_list(filters) do
    with {:ok, state} <- Filter.Prep.prep_state(spec, filters, deffs) do
      query
      |> Filter.Join.add_joins(state)
      |> Filter.Expr.build_expr(state, builder)
      |> Filter.Order.column_order(state)
      |> case do
        {:error, _} = pass -> pass
        query -> {:ok, query}
      end
    end
  end
end
