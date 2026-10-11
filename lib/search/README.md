# Rivet Search

Search columns(filters) on tables with a dynamic ecto query builder system.

## Using(Elixir)

Typical usage pattern:

```elixir
defmodule MyApp.RivetModel.Search do
  @col_schema [
    status: [type: :atom, list: :in],
    name: [type: :glob],
    owner: [type: :glob, key: :name, join: &fjoin_to_owner/3],
    inserted_at: [type: :date, order: :only],
    updated_at: [type: :date, order: :only]
  ]

  @default_filter [[n: "name"]]

  use Rivet.Search, schema: @col_schema, default_filters: @default_filters

  @impl Rivet.Search
  def filter_expr(:name, ..)

```

This will generate a search function that supports a map with either `:filter` or `:id` as a key (filter taking priority).

Options you can give to the creation of a search model:

  * `:schema` - REQUIRED (see SPEC/column schema).
  * `:default_filters` - default filter set when no user-supplied filters are provided (infills missing columns too).
  * `:soft_limit` - default=25 - this is the default result limit if there is not a user-supplied limit.
  * `:hard_limit` - default=400 - this is the max a user-supplied limit can have.

## Pagination

See [Pagination](pagination.md)

## Search Filters

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

```javascript
  [
    {n: "location", o: "a", v: ["a-location-name"]},
    {n: "serial", v: ["Q53"]},
    {n: "loc"},
    {n: "cond", v: ["failing", "servicing"], x: "no"},
    {n: "sku"}
  ]
```

## Search Schema

Concurrently, a column scheme is defined on the backend code, which is used by
prep_filters. The schema defines how to parse the filters, and enriches a filter
struct to be used to build the query.

The scheme is key/value map, where the key (atom) matches the name specified in
the filter (`n:` attribute). The value is a dict specification:

    type: {type}   — see below for built-in types. You can add custom types by
                     also defining prep and order.
    list:          - (default: false), may also be :in, in which case the value
                     must be a list and 'x in y' is used as the query.
    key: :atom     — the key used to reference the data on the model. Used only
                     when it does not match the scheme's parent key.
  {xx-name: <auto>   - auto generates to match the scheme filter key, unless changed}
    join: &func/3  — function to call to build a join if defaults are not wanted
     (or) {key, &func/3} — join function like above, but stored into an alt key
                     on the filter (when two diff filters will alter the same
                     order, like `:vlan` and `:vlan_id` — the latter can specify
                     that it is just `:vlan` order).
    prep: &func/*  - additional preparing of an arg/value beyond the built-ins,
                     supporting arity 1, 2, and 3.
    order: false   — if false, do not include in ordering (default: true)
    order: :only   — if `:only` only use it for order, not anything else
      (or) &func/4 — if it is a function, call that to generate the order value

Input Validation
################

Input validation happens in two cycles. The type can provide a function hook
for doing complex input validation & handling, or it can use a built-in type.
The built-in types are very simple. For complex things, use the hooked typing.

Built-in types:

   :string   - just take it verbatim as a string
   :glob     - trim & wrap it in % # todo: strip out dangerous things?
   :uuid     - match uuid pattern
   :atom     - turn it into an existing atom (not bespoke atom)
   :integer  — turn it into an integer
   :float    — turn it into a float
   :date     — turn it into a datetime

Schema for GraphQL should include:

```elixir
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
```

then it can be used simply as:

```elixir
  arg(:filter, list_of(:filter_column), default_value: [])
```
