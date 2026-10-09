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
    Rivet.Config.build(opts, Application.get_env(app, :rivet, []))
  end

  @doc """
  External interface to get migrations ready for use by Ecto
  """
  def prepare_project_migrations(opts, app) do
    with {:ok, config} <- config_build(opts, app),
         {:ok, %{idx: idx}} <- load_migrations_from_config(config),
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
  defp load_migrations_from_config(%{optsd: %{mig_dir}} = rivet_config) do
    with {:ok, mig_file} <- Rivet.Config.valid_file([mig_dir, @migrations_file], "migrations"),
         {:ok, mig_data} <- load_data_file(mig_file),
         do: load_project_migrations(@initial_state, mig_data, rivet_config)
  end

  defp load_project_migrations(state, [model_migration | rest], config)
       when is_list(model_migration) and is_map(state) do
    with {:ok, state} <- load_project_migration(Map.new(model_migration), state, config),
         do: load_project_migrations(state, rest, config)
  end

  defp load_project_migrations(%{idx: _, mods: _} = state, [], _), do: {:ok, state}

  defp load_project_migrations({:error, _} = pass, _, _), do: pass

  ##############################################################################
  def prepare_model_config(%{include: mod} = mig, mig_dir) do
    with {:ok, path} <- Rivet.Config.valid_dir([mig_dir, mod], "model migration path"),
         do: {:ok, %{struct(Rivet.Migration, mig) | path}}
  end

  defp load_project_migration(%{include: _} = model_migration, state, %{optsd}) do
    with {:ok, mig} <- prepare_model_config(model_migration, optsd.mig_dir) do
      {:ok, state}
      |> merge_model_migrations(mig, @index_file, true)
      |> merge_model_migrations(mig, @archive_file, optsd[:archive] == true)
    end
  end

  defp load_project_migration(%{external: extapp} = model_migration, state, cfg) do
    appdir = Rivet.Config.get_app_dir(cfg.optsd, extapp)

    with {:ok, config} <- config_build(cfg.fwd_opts ++ [base_dir: appdir], extapp),
         do: load_project_migrations(state, model_migration.migrations, config)
  end

  defp load_project_migration(model_migration, _, _),
    do: {:error, "Invalid migration (no include or external key): #{inspect(model_migration)}"}

  ##############################################################################
  def merge_model_migrations({:ok, _} = pass, _, _, false), do: pass

  def merge_model_migrations({:ok, state}, mig, file, _) do
    with {:ok, includes} <- load_data_file(Rivet.Config.clean_path([mig.path, file])),
         do: flatten_include(state, includes, mig)
  end

  def merge_model_migrations({:error, _} = pass, _, _, _), do: pass

  # # # # #
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

  ##############################################################################
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

  defp format_index(prefix, v) when prefix <= 9999 and v <= 99_999_999_999_999,
    do: {:ok, as_int!(pad("#{prefix}", 4, "0") <> pad("#{v}", 14, "0"))}

  defp format_index(p, v), do: {:error, "Prefix '#{p}' or version '#{v}' out of bounds"}
end
