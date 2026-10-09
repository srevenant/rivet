defmodule Rivet.Search.Filter.Prep do
  import Transmogrify.As
  alias Rivet.Search.Filter
  import Rivet.Guards

  ####################
  def prep_state(specs, cols, default_filter, meta \\ %{})

  def prep_state(specs, [], default_filter, meta),
    do: prep_state_reducer(%Filter.State{specs, meta}, default_filter)

  def prep_state(specs, cols, default_filter, meta),
    do: prep_state_reducer(%Filter.State{specs, meta}, enrich_defaults(cols, default_filter))

  # insert a default filter if they don't already exist in cols
  # ... if we want defaults first not user stuff first, flip ++ cols to the end
  # ... also: if a default value has additional opts and the user-supplied version
  #     does not, this will lose the default value. TBD if this is what we want
  #     or not...
  defp enrich_defaults(cols, defaults) do
    cols ++
      Enum.reject(defaults, fn %{n: n} ->
        Enum.any?(cols, &(&1.n == n))
      end)
  end

  ####################
  defp prep_state_reducer(state, [%{n: name} = fltr | rest]) do
    with {:ok, spec} <- get_filter_spec(name, state.specs),
         {:ok, fltr} <- init_filter(fltr),
         {:ok, state, fltr} <- validate_type(state, spec, fltr),
         {:ok, order} <- Filter.Order.prep_order(state, fltr, spec),
         {:ok, joins} <- Filter.Join.prep_join(state.joins, spec),
         do: prep_state_reducer(%{state | order, joins}, rest)
  end

  defp prep_state_reducer(state, []),
    do: {:ok, %{state | order: Keyword.values(state.order) |> Enum.reverse()}}

  ####################
  defp badcol(name), do: {:error, "Invalid column '#{name}' — not in spec"}

  defp get_filter_spec(name, specs) do
    case as_existing_atom(name) do
      {:ok, name} ->
        case specs[name] do
          nil ->
            badcol(name)

          opts ->
            {:ok,
             %{
               type: opts[:type],
               list: opts[:list] || false,
               name: name,
               # key is the model name
               key: opts[:key] || name,
               join: opts[:join],
               prep: opts[:prep],
               order: opts[:order]
             }}
        end

      # not valid pre-existing atom, thus can't be in the spec
      :error ->
        badcol(name)
    end
  end

  ####################
  @default_filter %{v: nil, x: :is, o: :a}
  defp init_filter(f), do: Map.merge(@default_filter, f) |> init_value()

  defp init_value(%{v: [""]} = f), do: {:ok, %{f | v: :no_value}}
  defp init_value(%{v: []} = f), do: {:ok, %{f | v: :no_value}}
  defp init_value(%{v: v} = f) when is_list(v), do: {:ok, f}
  defp init_value(%{v: nil} = f), do: {:ok, %{f | v: :no_value}}

  defp init_value(%{v: v}),
    do: {:error, "Invalid search filter param value (not a list?) #{inspect(v)}"}

  ##############################################################################
  defp validate_type(state, %{order: :only}, f), do: {:ok, state, f}

  defp validate_type(state, spec, %{v: value} = fltr) do
    with {:ok, value} <- validate_type_reducer(value, spec, [], state) do
      fltr = %{fltr | v: value}
      {:ok, %{state | values: Map.put(state.values, spec.name, fltr)}, fltr}
    end
  end

  ##########
  defp validate_type_reducer([v | rest], spec, out, state) do
    with {:ok, v} <- validate_type_value(v, spec, state),
         do: validate_type_reducer(rest, spec, [v | out], state)
  end

  defp validate_type_reducer(:no_value = v, spec, out, state) do
    with {:ok, v} <- validate_type_value(v, spec, state),
         do: {:ok, [v | out]}
  end

  defp validate_type_reducer([], %{list: :in}, out, _), do: {:ok, out}
  defp validate_type_reducer([], _, [out], _), do: {:ok, out}

  defp validate_type_reducer(_, s, _, _),
    do: {:error, "Invalid values for filter column '#{s.name}'"}

  ##############################################################################
  #
  # built-in type prep; they all come in as strings

  defp validate_type_value(value, %{prep: func}, _) when is_function(func, 1),
    do: func.(value)

  defp validate_type_value(value, %{prep: func} = spec, _) when is_function(func, 2),
    do: func.(value, spec)

  defp validate_type_value(value, %{prep: func} = spec, state) when is_function(func, 3),
    do: func.(value, spec, state)

  defp validate_type_value(:no_value, _, _), do: {:ok, :no_value}

  defp validate_type_value(value, %{type: :glob}, _),
    do: {:ok, "%#{String.trim(value)}%"}

  defp validate_type_value(value, %{type: :atom, name: key}, _) do
    with :error <- as_existing_atom(value),
         do: {:error, "Invalid value for #{key}: #{inspect(value)}"}
  end

  defp validate_type_value(value, %{type: :string}, _),
    do: {:ok, value}

  defp validate_type_value(value, %{type: :integer, name: key}, _) do
    with :error <- as_int(value),
         do: {:error, "Invalid value for #{key}: (int) #{inspect(value)}"}
  end

  defp validate_type_value(value, %{type: :float, name: key}, _) do
    with :error <- as_float(value),
         do: {:error, "Invalid value for #{key}: (float) #{inspect(value)}"}
  end

  defp validate_type_value("now", %{type: :date}, _), do: {:ok, DateTime.utc_now()}

  defp validate_type_value(value, %{type: :date, name: key}, _) do
    case DateTime.from_iso8601(value) do
      {:error, why} -> {:error, "Invalid ISO8601 Date for #{key}: #{why}"}
      {:ok, utctime, _} -> {:ok, utctime}
    end
  end

  defp validate_type_value(value, %{type: :uuid, name: key}, _) do
    if is_uuid(value),
      do: {:ok, value},
      else: {:error, "Invalid value for #{key}: not a uuid"}
  end

  defp validate_type_value(_value, badspec, _) do
    # this is a literal code problem and shouldn't happen in general use
    {:error, "Bad item spec? (#{inspect(badspec)})"}
  end

  ##############################################################################
  def prep_enum_any(:no_value, _, _), do: {:ok, :any}
  def prep_enum_any("any", _, _), do: {:ok, :any}
  def prep_enum_any(a, b, c), do: prep_enum(a, b, c)
  def prep_enum_mine("mine", _, _), do: {:ok, :mine}
  def prep_enum_mine(a, b, c), do: prep_enum(a, b, c)

  def prep_enum(value, _spec, enum) do
    with :error <- enum.cast(value),
         do: {:error, "Invalid #{Rivet.Utils.Module.mod_basename(enum)}: '#{value}'"}
  end
end
