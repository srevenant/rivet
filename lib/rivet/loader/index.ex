defmodule Rivet.Loader do
  alias Rivet.Loader.State
  import Rivet.Loader.Tools
  import Rivet.Utils.Cli.Print

  @callback load_data(meta :: State.t(), data :: map()) :: {:ok | :error, meta :: State.t()}
  @callback load_deferred(meta :: State.t(), data :: map()) :: {:ok | :error, meta :: State.t()}
  @optional_callbacks load_deferred: 2

  # wraps load_file, but handles the error and dies
  def load_or_die(fname, opts \\ []) do
    with {:error, %{log: log}} <- load_file(fname, opts) do
      die(log)
    end
  end

  def load_print_log(fname, opts \\ []) do
    with {ok?, %{log: log}} <- load_file(fname, opts) do
      IO.puts(log)
      ok?
    end
  end

  def load_file(fname, opts \\ []) do
    case find_load_file(fname) do
      {:error, reason} ->
        IO.puts(:stderr, reason)
        {:error, %{log: [reason]}}

      {:ok, path} ->
        YamlElixir.read_all_from_file(path, atoms: false)
        |> handle_yaml_result
        |> load_data(loader_state(opts ++ [path: path]))
        |> handle_exit
    end
  end

  defp handle_exit({how, %{log: log} = state}),
    do: {how, Map.put(state, :log, Enum.reverse(log))}

  ##############################################################################
  def loader_state(attrs) do
    keys = Map.keys(%Rivet.Loader.State{})
    attrs = Keyword.take(attrs, keys) ++ [opts: Map.new(Keyword.drop(attrs, keys))]

    case State.build(attrs) do
      %{path: path} = state when is_binary(path) ->
        log(state, "=> FILE #{path}")

      state ->
        state
    end
  end

  ##############################################################################
  # expects a sequence of docs
  @spec load_data({:ok, docs :: list()} | {:error, msg :: binary()}, state :: State.t()) ::
          {:ok | :error, state :: State.t()}

  def load_data({:error, msg}, %State{} = state), do: abort(state, msg)

  def load_data(
        {:ok, [%{version: version, type: file_type} = doc | data]},
        %State{load_file_type: file_type} = state
      ) do
    if state.min_file_ver <= version and version <= state.max_file_ver do
      if not is_nil(state.limits) and not match_limits?(state, doc) do
        {:ok, log(state, "-- Ignoring file; limits don't match")}
      else
        load_data_items({:ok, state}, data)
      end
    else
      {:error,
       log(
         state,
         "File version unsupported (min=#{state.min_file_ver}, max=#{state.max_file_ver})"
       )}
    end
  end

  def load_data({:ok, _}, %State{} = state) do
    {:error, log(state, "Unrecognized config file type (not #{state.load_file_type})")}
  end

  ##############################################################################
  defp load_or_die({q, %State{}} = pass, _, _) when q in [:ok, :error], do: pass

  defp load_or_die(result, type, func) do
    IO.inspect(result, label: "\n!! FAILURE from #{type}.#{func}(), bad result")
    system_exit(1)
  end

  defp type_modules(prefix, type) do
    [
      # Rivet style model "Loader" override
      {Module.concat([prefix, type, "Loader"]), :load_data, 2},
      # Rivet style model
      {Module.concat([prefix, type]), :create, 1},
      # Direct module reference
      {Module.concat([type, "Loader"]), :load_data, 2},
      {Module.concat([type]), :load_data, 2},
      {Module.concat([type]), :create, 1},
      # older 's' collection style
      {Module.concat([prefix, "#{type}s"]), :create, 1}
    ]
  end

  defp has_function?({module, func, arity}) do
    Code.ensure_loaded(module)
    Kernel.function_exported?(module, func, arity)
  end

  ##############################################################################
  defp find_run_load_module(state, data, type, [prefix | rest]) do
    case type_modules(prefix, type) |> Enum.find(&has_function?/1) do
      nil ->
        find_run_load_module(state, data, type, rest)

      {module, :load_data, 2} ->
        state = debug(state, "=> LOADER #{inspect(module)}")
        apply(module, :load_data, [state, data]) |> load_or_die(type, :load_data)

      {module, :create, 1} ->
        state = debug(state, "=> MODEL #{inspect(module)}")

        name =
          case data do
            %{id: id} -> [id: id]
            %{name: name} -> [name: name]
            %{label: label} -> [name: label]
            _ -> []
          end

        with {:ok, _, state} <- upsert_record(state, module, data, name), do: {:ok, state}
    end
  end

  defp find_run_load_module(state, _data, type, []) do
    list =
      Enum.reduce(state.load_prefixes, [], fn prefix, list ->
        type_modules(prefix, type) ++ list
      end)
      |> Enum.map(&inspect/1)
      |> Enum.join(", ")

    abort(state, "Cannot find module to load: #{type} (not one of: #{list})")
  end

  ##############################################################################
  @doc """

  If limits are given, it's a key:value dict. Rules:

  * If key does NOT exist in the doc, then it's evaluated true
  * If the key DOES exist, then the value must match to be true
  * If no limits, everything is true

  iex> alias Rivet.Loader.State
  iex> match_limits?(%State{limits: nil}, nil)
  true
  iex> match_limits?(%State{limits: %{env: "red"}}, %{env: "red"})
  true
  iex> match_limits?(%State{limits: %{env: "red"}}, %{env: "not red"})
  false
  iex> match_limits?(%State{limits: %{env: "red"}}, %{narf: "narf"})
  true
  iex> match_limits?(%State{limits: %{env: "red"}}, %{env: ["narf"]})
  false
  iex> match_limits?(%State{limits: %{env: "red"}}, %{env: ["narf", "red"]})
  true
  iex> match_limits?(%State{limits: %{env: ["red", "white", "blue"]}}, %{env: "red"})
  true
  iex> match_limits?(%State{limits: %{env: ["red", "white", "blue"]}}, %{env: ["red", "blue"]})
  true
  iex> match_limits?(%State{limits: %{env: ["red", "white", "blue"]}}, %{})
  true
  iex> match_limits?(%State{limits: %{env: ["red", "white", "blue"]}}, %{env: "purple"})
  false
  iex> match_limits?(%State{limits: %{env: ["red", "white", "blue"]}}, %{env: ["green"]})
  false
  """
  def match_limits?(%State{limits: nil}, _), do: true

  def match_limits?(%State{limits: limits}, map) do
    Enum.reduce_while(limits, true, fn {key, req}, _ ->
      if is_map_key(map, key) do
        case map[key] do
          val when is_list(val) ->
            if is_list(req) do
              Enum.any?(req, &(&1 in val))
            else
              req in val
            end

          val ->
            if is_list(req) do
              val in req
            else
              val == req
            end
        end
        |> if do
          {:cont, true}
        else
          {:halt, false}
        end
      else
        {:cont, true}
      end
    end)
  end

  ##############################################################################
  def load_data_items({:ok, %State{} = state}, [%{type: type, values: data} = doc | rest]) do
    if match_limits?(state, doc) do
      find_run_load_module(state, data, type, state.load_prefixes)
    else
      {:ok, state}
    end
    |> load_data_items(rest)
  end

  # ignore empty doc
  def load_data_items({:ok, %State{}} = pass, [x | rest]) when map_size(x) == 0,
    do: load_data_items(pass, rest)

  def load_data_items({:error, {%State{} = state, msg, data}}, _), do: abort(state, msg, data)
  def load_data_items({:error, %State{} = state} = error, _) when is_map(state), do: error

  def load_data_items({:ok, %State{deferred: deferred} = state}, []),
    do: load_deferred({:ok, state}, deferred)

  # force load deferred
  def load_data_items({:ok, %State{} = state}, [%{type: "load-deferred"} | rest]) do
    load_deferred({:ok, state}, state.deferred)
    |> load_data_items(rest)
  end

  # doc exists but didn't match format
  def load_data_items({:ok, %State{} = state}, [_doc | _]) do
    {:error, log(state, "Unrecognized doc, no type/values, cannot continue")}
  end

  def load_data_items(state, _) do
    IO.inspect(state, label: "Invalid state")
    {:error, log(state, "Received invalid state, cannot continue")}
  end

  ##############################################################################
  def load_deferred({:ok, %State{} = state}, [%{type: mod} = data | rest]) do
    apply(mod, :load_deferred, [state, data])
    |> load_or_die(mod, :load_deferred)
    |> load_deferred(rest)
  end

  def load_deferred({_, %State{}} = pass, _), do: pass

  ##############################################################################
  # defp defer_config(%State{} = state, %{id: id, mod: mod}) do
  #   with %{handlers: %{init: init} = h} = cached <- get_in(state, [:cache, mod, id]) do
  #     mod = Module.safe_concat([init])
  #     %{state | inits: [%{cached | handlers: Map.put(h, :init, mod)} | state.inits]}
  #   else
  #     _ ->
  #       state
  #   end
  # end

  # defp cache_data(state, mod, data), do: {:ok, cache_put(state, mod, data, data.id), data}
  #
  # defp cache_put(state, mod, data, key) do
  #   {state, mod_cache} =
  #     if Map.has_key?(state, :cache) do
  #       {state, get_in(state, [:cache, mod]) || %{}}
  #     else
  #       {Map.put(state, :cache, %{}), %{}}
  #     end
  #
  #   put_in(state, [:cache, mod], Map.put(mod_cache, key, data))
  # end
end
