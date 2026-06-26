defmodule Rivet.Loader.Tools do
  import Transmogrify
  import Rivet.Utils.Ecto.Errors, only: [convert_error_changeset: 1]
  alias Rivet.Loader.State

  def handle_yaml_result({:error, err}) do
    IO.inspect(err, label: "Bad YAML data")
    {:error, "Bad YAML data, cannot continue"}
  end

  def handle_yaml_result({:ok, data}) do
    {:ok, transmogrify(data, key_convert: :atom, key_case: :snake)}
  end

  @spec find_load_file(fname :: binary()) :: {:ok | :error, path :: binary()}
  def find_load_file(fname) do
    [fname, "../data/" <> fname, "/data/" <> fname, "../../../data/" <> fname]
    |> Enum.find(fn p ->
      case File.stat(p) do
        {:ok, _} -> true
        _ -> false
      end
    end)
    |> case do
      path when is_binary(path) ->
        {:ok, path}

      _ ->
        {:error, "Cannot find file: #{fname}"}
    end
  end

  def move_keys_if({:ok, out, src, defs}, [{key_name, func, opts} | rest]) do
    if Map.has_key?(src, key_name) do
      value = src[key_name]

      if func.(value) do
        move_keys_if(
          {:ok, Map.put(out, key_name, value), Map.delete(src, key_name), defs},
          rest
        )
      else
        {:error, "Invalid data for key #{inspect(key_name)}", src}
      end
    else
      case opts do
        %{required: false} ->
          move_keys_if({:ok, out, src, defs}, rest)

        _ ->
          if Map.has_key?(defs, key_name) do
            value = defs[key_name]
            out = Map.put(out, key_name, value)
            move_keys_if({:ok, out, src, defs}, rest)
          else
            {:error, "Unable to find default for #{inspect(key_name)}", defs}
          end
      end
    end
  end

  def move_keys_if(pass, []), do: pass

  def replace(mod, {keys, map}) when is_map(map) do
    keywords =
      Enum.map(keys, fn k ->
        if k in keys do
          {k, Map.get(map, k)}
        end
      end)

    mod.replace(map, keywords)
  end

  def create_list([item | items], mod) when is_tuple(item) do
    {:ok, _} = replace(mod, item)
    create_list(items, mod)
  end

  def create_list([], _mod), do: nil

  def modname(module), do: Module.split(module) |> List.last()

  def singular(module) do
    # using regex isn't efficient, but this is only for dataloads, and this is
    # much simpler code:
    Regex.replace(~r/s$/, "#{module}", "") |> String.to_atom()
  end

  ##############################################################################
  @spec upsert_record(
          state :: map(),
          collection :: atom(),
          data :: map(),
          claims :: list() | nil,
          commit :: function()
        ) ::
          {:ok, record :: map(), state :: map()}
          | {:error, state :: map()}

  def upsert_record(state, module, data, claims \\ nil, commit \\ &upsert_record_commit/4)

  def upsert_record(%State{commit: commit} = state, module, data, claims, _)
      when is_function(commit),
      do: upsert_record(state, module, data, claims, commit)

  def upsert_record(state, module, data, claims, commit) do
    with {:ok, item, state, type} <- commit.(state, module, data, claims) do
      {:ok, item,
       did_load(state, singular(module), item.id, "-- #{type} #{modname(module)} #{item.id}")}
    else
      err ->
        abort(state, "Upsert Record failed", err)
    end
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  # first try by ID, then by lookup criteria
  defp upsert_record_commit(state, module, %{id: id} = data, lookup)
       when is_binary(id) and byte_size(id) == 36 do
    replace_with_lookup(state, module, data, [id: id], fn _, _, _ ->
      replace_with_lookup(state, module, data, lookup)
    end)
  end

  # otherwise just go straight to lookup criteria
  defp upsert_record_commit(state, module, data, lookup),
    do: replace_with_lookup(state, module, data, lookup)

  # # # #
  defp replace_with_lookup(state, module, data, nil),
    do: create_record(state, module, data)

  defp replace_with_lookup(state, module, data, lookup, next \\ &create_record/3)

  defp replace_with_lookup(state, module, data, [], next),
    do: next.(state, module, data)

  defp replace_with_lookup(state, module, data, lookup, next) do
    case module.one(lookup) do
      {:ok, obj} ->
        case module.update(obj, data) do
          {:ok, obj} ->
            {:ok, obj, state, "UPDATE"}

          {:error, err} ->
            abort(state, "Unable to update record", err)
        end

      {:error, _} ->
        next.(state, module, data)
    end
  end

  # # # #
  defp create_record(state, module, data) do
    case module.create(data) do
      {:ok, obj} ->
        {:ok, obj, state, "CREATE"}

      err ->
        handle_create_error(err, state)
    end
  end

  defp handle_create_error({0, _}, state),
    do: abort(state, "Unable to change record ID")

  defp handle_create_error({:error, %Ecto.Changeset{} = chg}, state),
    do: abort(state, "Unable to create record", convert_error_changeset(chg))

  defp handle_create_error({:error, msg}, state),
    do: abort(state, "Unable to create record", msg)

  ##############################################################################
  def did_load(state, type, id, msg \\ nil) do
    state
    |> log(msg)
    |> Map.update(:loaded, %{}, fn loaded ->
      Map.update(loaded, type, MapSet.new([id]), &MapSet.put(&1, id))
    end)
    |> Map.update(:previous, %{type => id}, &Map.put(&1, type, id))
  end

  def next_in_order(item, state, key) do
    order = Map.get(state, key, 0)
    {:ok, Map.put(item, :order, order), Map.put(state, key, order + 1)}
  end

  def reset_order(state, key) do
    Map.delete(state, key)
  end

  def get_previous(state, type) do
    get_in(state, [:previous, type])
  end

  def get_previous_ids(data, [key | keys], state) do
    get_previous_id(data, key, state)
    |> get_previous_ids(keys, state)
  end

  def get_previous_ids(data, [], _), do: data

  def get_previous_id(data, key, state) do
    case Map.get(data, key) do
      "@previous " <> prev_type ->
        modkey = String.to_atom("Elixir.Rivet.#{prev_type}")

        case Map.get(state.previous, modkey) do
          nil ->
            abort(state, "@previous value #{prev_type} undefined, cannot continue")

          value ->
            Map.put(data, key, value)
        end

      _value ->
        data
    end
  end

  ##############################################################################
  def defer(%State{} = state, item) do
    %{state | deferred: [item | state.deferred]}
  end

  ##############################################################################
  def abort(state, msg, data \\ nil)

  def abort(state, msg, {:error, %Ecto.Changeset{} = chg}),
    do: abort(state, msg, convert_error_changeset(chg))

  def abort(state, msg, %Ecto.Changeset{} = chg),
    do: abort(state, msg, convert_error_changeset(chg))

  def abort(_, msg, {:error, state}) when is_map(state),
    do: abort(state, msg, nil)

  def abort(state, msg, nil) when is_map(state) and is_binary(msg),
    do: {:error, log(state, "!! " <> msg)}

  def abort(state, msg, data) when is_map(state) and is_binary(msg),
    do: {:error, debug(Map.put(state, :debug, true), data, label: "!! " <> msg)}

  defp debug_inspect(data, label: label), do: label <> ": " <> inspect(data)
  defp debug_inspect(data, _), do: inspect(data)

  def debug(state, msg, opts \\ [])

  def debug(%State{debug: true} = state, {:error, %Ecto.Changeset{} = chg}, opts),
    do: log(state, debug_inspect(chg, opts))

  def debug(%State{debug: true} = state, %Ecto.Changeset{} = chg, opts),
    do: log(state, debug_inspect(chg, opts))

  def debug(%State{debug: true} = state, msg, label: label) when is_binary(msg),
    do: log(state, "#{label}: #{msg}")

  def debug(%State{debug: true} = state, msg, _) when is_binary(msg), do: log(state, msg)
  def debug(%State{debug: true} = state, msg, opts), do: log(state, debug_inspect(msg, opts))
  def debug(state, _, _), do: state

  def log_state(%State{debug: true} = state, msg) do
    IO.puts(:stderr, msg)
    Map.update(state, :log, [], fn log -> [[msg, "\n"] | log] end)
  end

  def log_state(state, msg), do: Map.update(state, :log, [], fn log -> [[msg, "\n"] | log] end)

  ##############################################################################
  def log(state, nil), do: state

  def log(state, msg), do: log_state(state, msg)

  # a more 'normal' exit
  def system_exit(how), do: exit({:shutdown, how})

  def meta_put(%State{meta: meta} = state, key, value),
    do: %State{state | meta: Map.put(meta, key, value)}

  def meta_merge(%State{meta: meta} = state, value),
    do: %State{state | meta: Map.merge(meta, value)}

  def meta_update(%State{meta: meta} = state, key, default, func),
    do: %State{state | meta: Map.update(meta, key, default, func)}
end
