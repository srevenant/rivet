defmodule Mix.Tasks.Rivet.New.Model do
  import Mix.Generator
  import Transmogrify
  import Rivet.Migration
  alias Rivet.Cli.Templates
  import Rivet.Utils.Cli
  import Rivet.Utils.Cli.Print
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

      :ok
    else
      {:error, msg} -> die(msg)
    end
  end

  def run(optcfg, _, _) do
    syntax(optcfg, "mix rivet.new model {model_name} [opts]")
  end
end
