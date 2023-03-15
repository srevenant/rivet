defmodule Rivet.Config do
  import Transmogrify
  require Logger
  use Rivet

  @moduledoc ~S"""
  Optional configurations can be specified as opts, or in the project spec
  under the key `:rivet`

    base_dir   - base folder for pathing. Defaults to '.'
    lib_dir    - lib folder from base of project. Default: "lib"
    test_dir   - test folder from base of project. Default: "test"
    models_dir - sub-folder in lib for models, default: "#{app_name}"
                 (to remove this, define models_dir as an empty string)

  From this we generate:

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
  # @spec build(Keyword.t(), Keyword.t()) :: {:ok, rivet_config()} | rivet_error()
  def build(opts, config) do
    case config[:app] do
      nil ->
        {:error, "Unable to find app configuration in config?"}

      app ->
        rivet_conf = config[:rivet] || []
        basedir = getdir(:base_dir, opts, rivet_conf, ".")
        libdir = getdir(:lib_dir, opts, rivet_conf, "lib")
        testdir = getdir(:test_dir, opts, rivet_conf, "test")
        modelsdir = getdir(:models_dir, opts, rivet_conf, "#{app}")

        with {:ok, paths} <- get_paths(basedir, modelsdir, libdir, testdir) do
          {:ok,
           %{
             base_path: Path.join(basedir),
             app: app,
             base: modulename(getconf(:app_base, opts, rivet_conf, "#{app}")),
             opts: opts
           }
           |> Map.merge(paths)}
        end
    end
  end

  # def cleandir(path) do
  #   (Path.split(path) |> Path.join()) <> "/" |> String.replace(~r{/\./}, "/")
  # end

  # so we can get an empty string not falsey
  defp getdir(key, opts, conf, default), do: getconf(key, opts, conf, default) |> Path.split()

  defp getconf(key, opts, conf, default) do
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

  defp join_parts(list) do
    list
    |> Enum.filter(&(&1 != "."))
    |> case do
      [] -> ["."]
      p -> p
    end
    |> Path.join()
  end

  defp get_paths(basedir, modelsdir, libdir, testdir) do
    models_root = join_parts(basedir ++ libdir ++ modelsdir)

    if File.dir?(models_root) do
      {:ok, %{models_root: models_root, tests_root: join_parts(basedir ++ testdir ++ modelsdir)}}
    else
      {:error, "Models root folder '#{models_root}' doesn't exist"}
    end
  end
end
