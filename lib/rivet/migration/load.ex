defmodule Rivet.Migration.Load do
  require Logger
  import Rivet.Migration
  import Transmogrify.As
  import Transmogrify
  use Rivet

  @initial_state %{idx: %{}, mods: %{}}

  defp module_loaded?(mod, file) do
    if Code.ensure_loaded?(mod) do
      true
    else
      Code.require_file(file)
      true
    end
  rescue
    _ ->
      false
  end

  def config_build(opts, app) do
    Application.ensure_loaded(app)
    app_config = Application.get_env(app, :rivet, [])

    Keyword.put(app_config, :opts, opts) |> Map.new()
  end

  @doc """
  External interface to get migrations ready for use by Ecto
  """
  # @spec prepare_project_migrations(opts :: list(), project_config :: list()) ::
  #         {:ok, rivet_migrations()} | rivet_error()
  def prepare_project_migrations(opts, app) do
    config = config_build(opts, app)

    with {:ok, %{idx: idx}} <- load_migrations_from_config(config),
         do: {:ok, Map.keys(idx) |> Enum.sort() |> Enum.map(&idx[&1])}
  end

  def to_ecto_migrations(migs) do
    {:ok,
     Enum.map(migs, fn %{module: mod, index: ver, path: path} ->
       if module_loaded?(mod, path) and function_exported?(mod, :__migration__, 0) do
         {ver, mod}
       else
         raise Ecto.MigrationError, "Module #{mod} in #{path} does not define an Ecto.Migration"
       end
     end)}
  end

  ##############################################################################
  # @spec load_project_migrations(rivet_config()) :: {:ok, rivet_migrations()} | rivet_error()
  defp load_migrations_from_config(rivet_config) do
    rivet_dir = Application.app_dir(rivet_config.app, "priv/rivet/migrations")
    migfile = Path.join(rivet_dir, @migrations_file)

    if not File.exists?(migfile) do
      {:error, "Migrations file is missing (#{migfile})"}
    else
      with {:ok, mig_data} <- load_data_file(migfile),
           do: load_project_migrations(@initial_state, mig_data, rivet_config)
    end
  end

  # @spec load_project_migrations(
  #         rivet_migration_state(),
  #         list(rivet_migration_input_include() | rivet_migration_input_external()),
  #         rivet_config()
  #       ) ::
  #         rivet_state_result()
  defp load_project_migrations(state, [model_migration | rest], config)
       when is_list(model_migration) and is_map(state) do
    with {:ok, state} <- load_project_migration(Map.new(model_migration), state, config),
         do: load_project_migrations(state, rest, config)
  end

  defp load_project_migrations(%{idx: _, mods: _} = state, [], _), do: {:ok, state}

  defp load_project_migrations({:error, _} = pass, _, _), do: pass

  ##############################################################################
  # @spec load_project_migration(
  #         rivet_migration_input_include() | rivet_migration_input_external(),
  #         rivet_migration_state(),
  #         rivet_config()
  #       ) ::
  #         rivet_state_result()
  defp load_project_migration(
         %{include: _} = model_migration,
         state,
         %{opts: opts} = rivet_config
       ) do
    with {:ok, model_mig} <- prepare_model_config(model_migration, rivet_config) do
      {:ok, state}
      |> merge_model_migrations(model_mig, @index_file, true)
      |> merge_model_migrations(model_mig, @archive_file, opts[:archive] == true)
    end
  end

  defp load_project_migration(%{external: extapp} = model_migration, state, _cfg) do
    appdir = Application.app_dir(extapp)
    config = config_build([base_dir: appdir], extapp)
    load_project_migrations(state, model_migration.migrations, config)
  end

  defp load_project_migration(model_migration, _, _),
    do: {:error, "Invalid migration (no include or external key): #{inspect(model_migration)}"}

  ##############################################################################
  # @spec prepare_model_config(rivet_migration_input_any(), rivet_config()) :: {:ok, Rivet.Migration.t()} | rivet_error()
  def prepare_model_config(%{include: modpath} = model_migration, %{app: app}) do
    priv_dir = Application.app_dir(app, ["priv/rivet/migrations", modpath])
    {:ok, %Rivet.Migration{struct(Rivet.Migration, model_migration) | path: priv_dir}}
  end

  ##############################################################################
  # @spec merge_model_migrations(
  #         rivet_error() | {:ok, rivet_migration_state()},
  #         rivet_config(),
  #         String.t(),
  #         boolean()
  #       ) ::
  #         rivet_state_result()
  def merge_model_migrations({:ok, _} = pass, _, _, false), do: pass

  def merge_model_migrations({:ok, state}, mig, file, _) do
    with {:ok, includes} <- load_data_file(Path.join([mig.path, file])),
         do: flatten_include(state, includes, mig)
  end

  def merge_model_migrations({:error, _} = pass, _, _, _), do: pass

  # # # # #
  # @spec flatten_include(rivet_migration_state(), list(map()), rivet_config()) ::
  #         rivet_state_result()
  defp flatten_include(state, [mig | rest], model_cfg) do
    with {:ok, %{index: ver, module: mod} = mig} <- flatten_migration(model_cfg, Map.new(mig)) do
      if Map.has_key?(state.idx, ver) or Map.has_key?(state.mods, mod) do
        Logger.error("Ignoring duplicate migration: #{inspect(Map.to_list(mig))}")
        state
      else
        %{state | idx: Map.put(state.idx, ver, mig), mods: Map.put(state.mods, mod, [])}
      end
      |> flatten_include(rest, model_cfg)
    end
  end

  defp flatten_include(state, [], _) when is_map(state), do: {:ok, state}

  # # # # #
  # @spec flatten_migration(map(), rivet_migration_input_model()) ::
  #         {:ok, Rivet.Migration.t()} | rivet_error()
  defp flatten_migration(
         %Rivet.Migration{prefix: prefix, include: include, path: path},
         %{
           version: ver,
           module: module
         } = mig
       ) do
    with {:ok, index} <- format_index(prefix, ver) do
      {:ok,
       %Rivet.Migration{
         base: Map.get(mig, :base, false),
         version: ver,
         index: index,
         prefix: prefix,
         parent: as_module(include),
         module: module,
         path: "#{path}/#{pathname(module) |> Path.basename()}.exs"
       }}
    end
  end

  # @spec format_index(integer(), integer()) :: {:ok | :error, String.t()}
  defp format_index(prefix, v) when prefix <= 9999 and v <= 99_999_999_999_999,
    do: {:ok, as_int!(pad("#{prefix}", 4, "0") <> pad("#{v}", 14, "0"))}

  defp format_index(p, v), do: {:error, "Prefix '#{p}' or version '#{v}' out of bounds"}
end
