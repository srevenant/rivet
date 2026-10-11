defmodule Rivet.Search.Filter.Prep do
  @moduledoc """

  Prepares search filters into a normalized `%Filter.State{}`.

  User-supplied filters override defaults by column name. Values are validated
  and converted according to their column specs.

  Missing values normalize to `[:no_value]` unless transformed by custom
  prep function in the spec. A custom prep function can return `:skip` to
  exclude an individual filter entirely.

  """

  import Transmogrify.As
  alias Rivet.Search.Filter
  import Rivet.Guards

  ####################

  @spec prep_state(map(), [map()], [map()], map()) :: {:ok, Filter.State.t()} | {:error, term()}
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
         {:ok, fltr} <- init_filter(fltr, spec) do
      case validate_type(state, spec, fltr) do
        :skip ->
          prep_state_reducer(state, rest)

        {:ok, state, fltr} ->
          with {:ok, order} <- Filter.Order.prep_order(state, fltr, spec),
               {:ok, joins} <- Filter.Join.prep_join(state.joins, spec),
               do: prep_state_reducer(%{state | order, joins}, rest)

        {:error, _} = error ->
          error
      end
    end
  end

  defp prep_state_reducer(state, []),
    do: {:ok, %{state | order: Keyword.values(state.order) |> Enum.reverse()}}

  defp prep_state_reducer(_, [_ | _]),
    do: {:error, "Invalid search filter: missing column name"}

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

  ##############################################################################
  @default_filter %{v: nil, x: :is, o: nil}
  defp init_filter(f, spec) do
    f = Map.merge(@default_filter, f)
    with {:ok, o} <- resolve_order(f.o, spec[:order]), do: init_value(%{f | o})
  end

  ###############
  defp init_value(%{v: nil} = f), do: {:ok, %{f | v: :no_value}}

  defp init_value(%{v} = f) when is_list(v) do
    if Enum.all?(v, &is_binary/1) do
      case Enum.reject(v, &(String.trim(&1) == "")) do
        [] -> {:ok, %{f | v: :no_value}}
        v -> {:ok, %{f | v}}
      end
    else
      bad_value_error(v)
    end
  end

  defp init_value(%{v}), do: bad_value_error(v)

  ###############
  defp bad_value_error(v), do: {:error, "Invalid search filter value: #{inspect(v)}"}

  ##############################################################################
  # no given order, take spec :desc setting
  def resolve_order(nil, d) when d in [:asc, :desc], do: {:ok, d}
  def resolve_order(nil, _), do: {:ok, :asc}
  def resolve_order(:a, _), do: {:ok, :asc}
  def resolve_order(:d, _), do: {:ok, :desc}
  def resolve_order(x, _), do: {:error, "Invalid filter order: #{inspect(x)}"}

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

  defp validate_type_reducer([], %{name, list: :in}, out, _) do
    # make sure our helper didn't give us bad data. It can return data parsed
    # so things NOT binary, and that's fine. Just don't mix in :no_value too
    cond do
      out == [:no_value] -> {:ok, out}
      :no_value in out -> {:error, "Invalid values for filter column '#{name}'"}
      true -> {:ok, Enum.reverse(out)}
    end
  end

  defp validate_type_reducer([], _, [:no_value], _), do: {:ok, [:no_value]}
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

  defp validate_type_value(value, %{type: :glob}, _) do
    value =
      String.trim(value)
      |> String.replace("\\", "\\\\")
      |> String.replace("%", "\\%")
      |> String.replace("_", "\\_")

    {:ok, "%#{value}%"}
  end

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
end
