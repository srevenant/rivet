defmodule Rivet.Config do
  import Transmogrify
  require Logger
  use Rivet

  @moduledoc ~S"""
  Optional configurations can be specified as opts, or in the app environment
  under the key `:rivet`

    base_dir   - base folder of the project, for pathing. Defaults to '.'
    lib_dir    - lib folder from base of project. Default: "lib"
    test_dir   - test folder from base of project. Default: "test"
    models_dir - sub-folder in lib_dir for models, default: "#{app_name}"
    priv_dir   - where is 'priv' located

  From this we generate:

    base:          - "Base.Module.Name" for models
    models_root:   - relative path to base for new models. Generated as:
                         "#{lib_dir}/#{app_dir}/#{mod_dir}"
    model_path:    - relative path to model base folder
                         "#{models_root}/#{model_base_name}
    tests_root:    - relative path to base test folder
                         "#{test_dir}/#{app_dir}/#{mod_dir}"
    test_path:     - relative path to model test folder
                         "#{tests_root}/#{model_base_name}"
    base_path:     - base folder for project
  """
  def build(prefs, rivet_conf) do
    case rivet_conf[:app] do
      nil ->
        {:error, "Unable to find app configuration in config?"}

      app ->
        with {:ok, base_dir} <- getdir(:base_dir, prefs, rivet_conf, "."),
             {:ok, lib_dir} <- getdir(:lib_dir, prefs, rivet_conf, "lib"),
             {:ok, test_dir} <- getdir(:test_dir, prefs, rivet_conf, "test"),
             {:ok, models_dir} <- getdir(:models_dir, prefs, rivet_conf, "#{app}", verify: false),
             base <- getconf!(:base, prefs, rivet_conf, modulename(models_dir)),
             {:ok, paths} <- get_roots(base_dir, models_dir, lib_dir, test_dir) do
          # partial, we'll do a second pass...
          optsd =
            Map.new(prefs)
            |> Map.merge(%{base_dir, lib_dir, test_dir, models_dir, priv_dir: nil, mig_dir: nil})

          def_priv = Path.join(get_app_dir(optsd, app), "priv")

          with {:ok, priv_dir} <- getdir(:priv_dir, prefs, rivet_conf, def_priv),
               {:ok, mig_dir} <- valid_dir([priv_dir, "rivet/migrations"], "migrations", false) do
            optsd = %{optsd | priv_dir, mig_dir}

            fwd_opts =
              Map.drop(optsd, [:base_dir, :lib_dir, :test_dir, :models_dir, :priv_dir, :mig_dir])

            {:ok,
             %{
               optsd,
               app,
               base,
               base_path: optsd[:base_dir],
               opts: Map.to_list(optsd),
               fwd_opts: Map.to_list(fwd_opts)
             }
             |> Map.merge(paths)}
          end
        end
    end
  end

  # so we can get an empty string not falsey
  defp getdir(key, prefs, conf, default, opts \\ []) do
    getconf!(key, prefs, conf, default)
    |> Path.split()
    |> valid_dir(key, Keyword.get(opts, :verify, true))
  end

  # wrap Application.get_dir so we can override it for testing
  def get_app_dir(optsd, app) do
    key = String.to_atom("#{app}_override")
    Map.get(optsd, key, Application.app_dir(app))
  end

  # # # # # # #
  def valid_file(list, key, verify? \\ true)

  def valid_file(list, key, verify?) when is_list(list),
    do: clean_path(list) |> valid_file(key, verify?)

  def valid_file(<<path::binary>>, key, true) do
    if File.exists?(path), do: {:ok, path}, else: {:error, "Rivet file #{key} does not exist"}
  end

  def valid_file(<<path::binary>>, _, false), do: {:ok, path}

  # # # # # # #
  def valid_dir(list, key, verify? \\ true)

  def valid_dir(list, key, verify?) when is_list(list),
    do: clean_path(list) |> valid_dir(key, verify?)

  def valid_dir(<<path::binary>>, key, true) do
    # if File.dir?(path), do: {:ok, path}, else: {:error, "Rivet dir #{key}=#{path} does not exist"}
    if File.dir?(path), do: {:ok, path}, else: raise("Rivet dir #{key}=#{path} does not exist")
  end

  def valid_dir(<<path::binary>>, _, false), do: {:ok, path}

  defp getconf!(key, opts, conf, default) do
    case opts[key] do
      nil ->
        case conf[key] do
          nil -> default
          pass -> pass
        end

      pass ->
        pass
    end
  end

  # remove redundant "." paths (just because), and if there is no path make sure its "."
  def clean_path(list) do
    list
    |> Enum.filter(&(&1 != "."))
    |> case do
      [] -> ["."]
      p -> p
    end
    |> Path.join()
  end

  defp get_roots(b_dir, m_dir, l_dir, t_dir),
    do:
      {:ok,
       %{
         models_root: clean_path([b_dir, l_dir, m_dir]),
         tests_root: clean_path([b_dir, t_dir, m_dir])
       }}
end
