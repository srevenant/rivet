defmodule DefEnum do
  defp normalize_enum!(ast, env) do
    pairs =
      case ast do
        list when is_list(list) ->
          Enum.map(list, fn
            {k_ast, v} ->
              {expand_key!(k_ast, env), v}

            other ->
              # coveralls-ignore-next-line
              raise ArgumentError,
                    "defenum list input must contain only 2-tuples, got: #{inspect(other)}"
          end)

        {:%{}, _, kvs} ->
          Enum.map(kvs, fn
            {k_ast, v} ->
              {expand_key!(k_ast, env), v}

            other ->
              # coveralls-ignore-next-line
              raise ArgumentError,
                    "defenum map input must contain only key/value pairs, got: #{inspect(other)}"
          end)

        other ->
          # coveralls-ignore-next-line
          raise ArgumentError,
                "defenum expects a keyword list, tuple list, or map, got: #{Macro.to_string(other)}"
      end

    validate_enum!(pairs)
    pairs
  end

  defp expand_key!(key_ast, env) do
    key = Macro.expand(key_ast, env)

    unless is_atom(key) do
      # coveralls-ignore-next-line
      raise ArgumentError,
            "defenum keys must expand to atoms/modules, got: #{Macro.to_string(key_ast)} => #{inspect(key)}"
    end

    key
  end

  def validate_enum!(kv_enum) do
    # this will require a valid Keyword list, or raise error
    # keys = Keyword.keys(kv_enum)
    # vals = Keyword.values(kv_enum)

    keys = Enum.map(kv_enum, &elem(&1, 0))
    vals = Enum.map(kv_enum, &elem(&1, 1))

    unless Enum.all?(vals, &is_integer/1) do
      raise ArgumentError, "defenum values must be integers, got: #{inspect(vals)}"
    end

    if length(Enum.uniq(keys)) != length(keys) do
      raise ArgumentError, "defenum keys must be unique: #{inspect(keys)}"
    end

    :ok
  end

  # def typespec_ast(keys) do
  #   case keys do
  #     [] -> quote(do: none())
  #     [k] -> k
  #     [k | rest] -> Enum.reduce(rest, k, fn key, acc -> {:|, [], [acc, key]} end)
  #   end
  # end
  def typespec_ast(keys) do
    quoted_keys =
      Enum.map(keys, fn key ->
        Macro.escape(key)
      end)

    case quoted_keys do
      [] -> quote(do: none())
      [k] -> k
      [k | rest] -> Enum.reduce(rest, k, fn key, acc -> {:|, [], [acc, key]} end)
    end
  end

  defp enum_body_ast(kv_enum_ast, env) do
    kv_enum = normalize_enum!(kv_enum_ast, env)
    validate_enum!(kv_enum)

    keys = Enum.map(kv_enum, &elem(&1, 0))
    t_ast = typespec_ast(keys)

    quote do
      @behaviour Ecto.Type

      @values unquote(Macro.escape(kv_enum))
      @params Ecto.Enum.init(values: @values)

      @typedoc "Enum keys for #{inspect(__MODULE__)}"
      @type t :: unquote(t_ast)

      @typedoc "Underlying stored integer values"
      @type value :: integer()

      ########## helpers, like for absinthe
      @spec values() :: [t()]
      def values, do: Keyword.keys(@values)

      @spec enum_map() :: %{required(t()) => value()}
      def enum_map, do: Map.new(@values)

      @spec __enum_map__() :: %{required(t()) => value()}
      def __enum_map__, do: enum_map()

      ##########
      @impl true
      def type, do: :integer

      @impl true
      def cast(value), do: Ecto.Enum.cast(value, @params)

      @impl true
      def load(value), do: Ecto.Enum.load(value, fn v -> {:ok, v} end, @params)

      @impl true
      def dump(value), do: Ecto.Enum.dump(value, fn v -> {:ok, v} end, @params)

      # def dump!(value) do
      #   with {:ok, v} <- dump(value), do: v
      # end

      def valid_value?(value) do
        case cast(value) do
          {:ok, _} -> true
          _ -> false
        end
      end

      @impl true
      def embed_as(_format), do: :self

      @impl true
      def equal?(a, b), do: a == b
    end
  end

  # creates a Module inline in the current module
  defmacro defenum(name, kv_enum_ast) do
    body = enum_body_ast(kv_enum_ast, __CALLER__)

    quote do
      defmodule unquote(name) do
        unquote(body)
      end
    end
  end

  # coveralls-ignore-start
  # just add the type info into the current Module
  defmacro defenum_type(kv_enum_ast) do
    enum_body_ast(kv_enum_ast, __CALLER__)
  end

  # coveralls-ignore-stop
end
