defmodule Rivet.Search.Validate do
  @moduledoc """

  Compile-time validation and normalization of search schema and defaults.

  These raise errors rather than returning tuples because its a compile-time problem.

  """

  @builtin_types [:string, :glob, :uuid, :atom, :integer, :float, :date]
  @schema_options [:type, :list, :key, :join, :prep, :order]

  ##############################################################################
  @spec schema(keyword() | map()) :: map()
  def schema(schema) do
    schema = config_map!(schema, "Search schema")

    Map.new(schema, fn {name, raw_opts} ->
      required!(
        is_atom(name) and not is_nil(name),
        "Search column is not an atom: #{inspect(name)}"
      )

      opts = config_map!(raw_opts, "Search column #{inspect(name)}")
      unknown = Map.keys(opts) -- @schema_options

      required!(unknown == [], "#{name}: unknown options #{inspect(unknown)}")
      validate_column!(name, opts)

      {name, opts}
    end)
  end

  ##############################################################################
  defp validate_column!(name, opts) do
    required!(
      is_nil(opts[:prep]) or valid_prep?(opts[:prep]),
      "#{name}: prep must be a function of arity 1, 2, or 3"
    )

    required!(
      opts[:type] in @builtin_types or not is_nil(opts[:prep]) or opts[:order] == :only,
      "#{name}: invalid type #{inspect(opts[:type])} (custom types need prep)"
    )

    required!(opts[:list] in [nil, false, :in], "#{name}: list must be false or :in")

    required!(is_nil(opts[:key]) or is_atom(opts[:key]), "#{name}: key must be an atom")

    required!(
      valid_join?(opts[:join]),
      "#{name}: join must be a function/3 or {atom, function/3}"
    )

    required!(
      opts[:order] in [nil, true, false, :only, :asc, :desc] or is_function(opts[:order], 4),
      "#{name}: invalid order #{inspect(opts[:order])}"
    )
  end

  ##############################################################################
  defp valid_prep?(fun), do: is_function(fun, 1) or is_function(fun, 2) or is_function(fun, 3)

  ##############################################################################
  defp valid_join?(nil), do: true
  defp valid_join?(fun) when is_function(fun, 3), do: true

  defp valid_join?({name, fun}) when is_atom(name) and not is_nil(name) and is_function(fun, 3),
    do: true

  defp valid_join?(_), do: false

  ##############################################################################
  @spec defaults(list(), map()) :: [map()]
  def defaults(default, schema) when is_list(default) and is_map(schema) do
    known = Enum.map(Map.keys(schema), &Atom.to_string/1)

    defaults =
      default
      |> Enum.with_index(1)
      |> Enum.map(fn {raw, index} ->
        f = config_map!(raw, "Search default ##{index}")

        name =
          case f[:n] do
            n when is_binary(n) -> n
            n when is_atom(n) and not is_nil(n) -> Atom.to_string(n)
            _ -> raise ArgumentError, "Search default ##{index}: missing or invalid n"
          end

        required!(name in known, "Search default: unknown column #{inspect(name)}")
        required!(f[:o] in [nil, :a, :d], "#{name}: invalid order #{inspect(f[:o])}")

        required!(
          is_nil(f[:v]) or (is_list(f[:v]) and Enum.all?(f[:v], &is_binary/1)),
          "#{name}: v must be a list of strings"
        )

        Map.put(f, :n, name)
      end)

    names = Enum.map(defaults, & &1.n)
    required!(length(names) == length(Enum.uniq(names)), "Duplicate search defaults")

    defaults
  end

  def defaults(_, _), do: raise(ArgumentError, "Search defaults must be a list")

  ##############################################################################
  defp config_map!(value, _) when is_map(value), do: value

  defp config_map!(value, context) when is_list(value) do
    required!(Keyword.keyword?(value), "#{context}: expected a keyword list")

    keys = Keyword.keys(value)
    required!(length(keys) == length(Enum.uniq(keys)), "#{context}: duplicate keys")

    Map.new(value)
  end

  defp config_map!(_, context),
    do: raise(ArgumentError, "#{context}: expected a map or keyword list")

  ##############################################################################
  defp required!(true, _), do: :ok
  defp required!(false, message), do: raise(ArgumentError, message)
end
