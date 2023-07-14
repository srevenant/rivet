defmodule Mix.Tasks.Rivet.New.Model do
  import Mix.Generator
  import Transmogrify
  import Rivet.Migration
  alias Rivet.Cli.Templates
  import Rivet.Utils.Cli
  alias Rivet.Migration
  use Rivet

  def run(optcfg, opts, [model_name]) do
    with {:ok, %{app: app, models_root: models_root, tests_root: tests_root, base: base} = cfg} <-
           Mix.Tasks.Rivet.New.get_config(optcfg, opts) do
      alias = String.split(base, ".") |> List.last()
      mod = Path.split(model_name) |> List.last()

      modeldir = Path.join(models_root, model_name)
      testdir = Path.join(tests_root, model_name)
      model = modulename(model_name)
      table = snakecase("#{alias}_#{String.replace(model, "/", "_")}")

      # prefix our config opts with `c_` so they don't collide with command-line opts
      opts =
        Keyword.merge(cfg.opts,
          c_app: app,
          c_base: base,
          c_model: model,
          c_factory: table,
          c_table: "#{table}s",
          c_mod: "#{base}.#{model}"
        )

      dopts = Map.new(opts)

      create_directory(modeldir)

      if dopts.model do
        create_file("#{modeldir}/model.ex", Templates.model(opts))
      end

      if dopts.lib do
        create_file("#{modeldir}/lib.ex", Templates.lib(opts))
      end

      if dopts.loader do
        create_file("#{modeldir}/loader.ex", Templates.empty(opts ++ [c_sub: "Loader"]))
      end

      if dopts.seeds do
        create_file("#{modeldir}/seeds.ex", Templates.empty(opts ++ [c_sub: "Seeds"]))
      end

      if dopts.graphql do
        create_file("#{modeldir}/graphql.ex", Templates.empty(opts ++ [c_sub: "Graphql"]))
      end

      if dopts.resolver do
        create_file("#{modeldir}/resolver.ex", Templates.empty(opts ++ [c_sub: "Resolver"]))
      end

      if dopts.rest do
        create_file("#{modeldir}/rest.ex", Templates.empty(opts ++ [c_sub: "Rest"]))
      end

      if dopts.cache do
        create_file("#{modeldir}/cache.ex", Templates.empty(opts ++ [c_sub: "Cache"]))
      end

      if dopts.test do
        create_directory(testdir)
        create_file("#{testdir}/#{mod}_test.exs", Templates.test(opts))
      end

      # note: keep this last for readability of the final message
      if dopts.migration do
        rivetmigdir = Application.app_dir(app, "priv/rivet/migrations")
        create_directory(rivetmigdir)
        create_file(Path.join([rivetmigdir, model_name, @index_file]), Templates.migrations(opts))

        create_file(
          Path.join([rivetmigdir, model_name, @archive_file]),
          Templates.empty_list(opts)
        )

        create_file(
          Path.join([rivetmigdir, model_name, "base.exs"]),
          Templates.base_migration(opts)
        )

        basemod = as_module("#{opts[:c_mod]}.Migrations")

        migrations_file = Path.join(rivetmigdir, @migrations_file)

        if not File.exists?(migrations_file) do
          create_file(migrations_file, Templates.empty_list(opts))
        end

        case Migration.Manage.add_include(migrations_file, basemod) do
          {:exists, _prefix} ->
            IO.puts("""

            Model already exists in `#{migrations_file}`, not adding

            """)

          {:ok, mig} ->
            IO.puts("""

            Model added to `#{migrations_file}` with prefix `#{mig[:prefix]}`

            """)

          {:error, error} ->
            IO.puts(:stderr, error)
        end
      end
    end

    :ok
  end

  def run(optcfg, _, _) do
    syntax(optcfg, "model {model_name}")
  end

  # ################################################################################
  # def syntax(_opts \\ nil) do
  #   cmd = Rivet.Utils.Cli.task_cmd(__MODULE__)
  #
  #   IO.puts(:stderr, """
  #   Syntax: mix #{cmd} model {path/to/model_folder (singular)} [options]
  #   Syntax: mix #{cmd} mig|migration {path/to/model_folder (singular)} {migration_name} [options]
  #
  #   Options:
  #   """)
  #
  #   list_options(@switches, @aliases, @switch_info)
  # end
  #
  # ## todo: bring in app defaults
  # def list_options(switches, aliases, info \\ []) do
  #   # invert aliases
  #   aliases =
  #     Map.new(aliases)
  #     |> Enum.reduce(%{}, fn {k, v}, acc ->
  #       Map.update(acc, v, [k], fn as -> [k | as] end)
  #     end)
  #
  #   # switches as strings for sorting
  #   Enum.map(switches, fn {k, _} -> to_string(k) end)
  #   |> Enum.sort()
  #   |> list_options(Map.new(switches), aliases, Map.new(info))

  # def list_options([option | rest], switches, aliases, info) do
  #   key = String.to_atom(option)
  #   list_option(String.replace(option, "_", "-"), key, switches[key], aliases[key], info[key])
  #   list_options(rest, switches, aliases, info)
  # end
  #
  # def list_options([], _, _, _), do: :ok
  #
  # def list_option(opt, _optkey, :boolean, _aliases, info) do
  #   {a, b} = if info[:default] == true, do: {"", "no-"}, else: {"no-", ""}
  #   # TODO: how does python list boolean defaults
  #   IO.puts(:stderr, "  --#{a}#{opt}|--#{b}#{opt}")
  # end
  #
  # def list_option(opt, _optkey, [type, :keep], _aliases, _info) do
  #   IO.puts(:stderr, "  --#{opt}=#{to_string(type) |> String.upcase()}")
  # end
end
