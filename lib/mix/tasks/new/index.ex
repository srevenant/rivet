defmodule Mix.Tasks.Rivet.New do
  use Mix.Task
  # alias Rivet.Cli.Templates
  # import Mix.Generator
  # import Transmogrify
  # require Logger
  import Rivet.Utils.Cli
  # import Rivet.Migration
  # # import Rivet.Migration.Manage
  # alias Rivet.Migration
  # use Rivet

  @shortdoc "Create a new Rivet Model or Model Migration. For full syntax try: mix rivet help"

  @moduledoc @shortdoc

  @optcfg [
    command: "mix rivet new",
    commands: [
      {"mod?el", Mix.Tasks.Rivet.New.Model},
      {"mig?ration", Mix.Tasks.Rivet.New.Migration}
    ],
    info: [
      model: [default: true],
      lib: [default: true],
      migration: [default: true],
      test: [default: true],
      loader: [default: false],
      seeds: [default: false],
      graphql: [default: false],
      resolver: [default: false],
      rest: [default: false],
      cache: [default: false]
    ],
    switches: [
      cache: :boolean,
      graphql: :boolean,
      lib: :boolean,
      model: :boolean,
      lib_dir: [:string, :keep],
      priv_dir: [:string, :keep],
      loader: :boolean,
      log_migrations_sql: :boolean,
      log_migrator_sql: :boolean,
      log_sql: :boolean,
      migration: :boolean,
      no_compile: :boolean,
      no_deps_check: :boolean,
      order: [:integer, :keep],
      prefix: :string,
      quiet: :boolean,
      repo: [:string, :keep],
      resolver: :boolean,
      rest: :boolean,
      seeds: :boolean,
      strict_version_order: :boolean,
      test: :boolean,
      test_dir: [:string, :keep]
    ],
    aliases: [
      m: :model,
      b: :lib,
      l: :loader,
      s: :seeds,
      g: :graphql,
      c: :cache,
      t: :test
    ],
    info: []
  ]

  @impl true
  def run(args), do: run_command(args, @optcfg)

  def get_config(optcfg, opts) do
    Mix.Task.run("app.config", [])
    app = Mix.Project.config()[:app]
    Application.ensure_loaded(app)
    rivetcfg = Application.get_env(app, :rivet, [])

    Keyword.merge(Keyword.get(optcfg, :info), opts) |> Rivet.Config.build(rivetcfg)
  end

  #
  # def run_cmd(args, opts) do
  #   case parse_options(args, opts) do
  #     {opts, args, []} ->
  #       Keyword.merge(Keyword.get(opts, :info), opts)
  #       |> Rivet.Config.build(Mix.Project.config())
  #       |> new(args)
  #
  #     {_, _, _errs} ->
  #       syntax(opts, "Bad arguments")
  #   end
  # end
  #
  # def new({:ok, cfg}, ["model", model_name]), do: configure_model(cfg, model_name)
  # def new({:ok, cfg}, ["mig", model, label]), do: handle_add_migration(model, label, cfg)
  # def new({:ok, cfg}, ["migration", model, label]), do: handle_add_migration(model, label, cfg)
  # def new(_, _), do: syntax()
  #
  # defp handle_add_migration(model, label, cfg) do
  #   case Migration.Manage.add_migration(model, label, cfg) do
  #     {:error, reason} ->
  #       IO.puts(:stderr, reason)
  #
  #     :ok ->
  #       :ok
  #       # other -> IO.inspect(other, label: "Unexpected result adding migration")
  #   end
  # end
  #
  # defp configure_model(
  #        %{app: app, models_root: models_root, tests_root: tests_root, base: base} = cfg,
  #        path_name
  #      ) do
  #   alias = String.split(base, ".") |> List.last()
  #   mod = Path.split(path_name) |> List.last()
  #
  #   modeldir = Path.join(models_root, path_name)
  #   testdir = Path.join(tests_root, path_name)
  #   model = modulename(path_name)
  #   table = snakecase("#{alias}_#{String.replace(model, "/", "_")}")
  #
  #   # prefix our config opts with `c_` so they don't collide with command-line opts
  #   opts =
  #     Keyword.merge(cfg.opts,
  #       c_app: app,
  #       c_base: base,
  #       c_model: model,
  #       c_factory: table,
  #       c_table: "#{table}s",
  #       c_mod: "#{base}.#{model}"
  #     )
  #
  #   dopts = Map.new(opts)
  #
  #   create_directory(modeldir)
  #
  #   if dopts.model do
  #     create_file("#{modeldir}/model.ex", Templates.model(opts))
  #   end
  #
  #   if dopts.lib do
  #     create_file("#{modeldir}/lib.ex", Templates.lib(opts))
  #   end
  #
  #   if dopts.loader do
  #     create_file("#{modeldir}/loader.ex", Templates.empty(opts ++ [c_sub: "Loader"]))
  #   end
  #
  #   if dopts.seeds do
  #     create_file("#{modeldir}/seeds.ex", Templates.empty(opts ++ [c_sub: "Seeds"]))
  #   end
  #
  #   if dopts.graphql do
  #     create_file("#{modeldir}/graphql.ex", Templates.empty(opts ++ [c_sub: "Graphql"]))
  #   end
  #
  #   if dopts.resolver do
  #     create_file("#{modeldir}/resolver.ex", Templates.empty(opts ++ [c_sub: "Resolver"]))
  #   end
  #
  #   if dopts.rest do
  #     create_file("#{modeldir}/rest.ex", Templates.empty(opts ++ [c_sub: "Rest"]))
  #   end
  #
  #   if dopts.cache do
  #     create_file("#{modeldir}/cache.ex", Templates.empty(opts ++ [c_sub: "Cache"]))
  #   end
  #
  #   if dopts.test do
  #     create_directory(testdir)
  #     create_file("#{testdir}/#{mod}_test.exs", Templates.test(opts))
  #   end
  #
  #   # note: keep this last for readability of the final message
  #   if dopts.migration do
  #     migdir = Path.join(modeldir, "migrations")
  #     create_directory(migdir)
  #     create_file(Path.join(migdir, @index_file), Templates.migrations(opts))
  #     create_file(Path.join(migdir, @archive_file), Templates.empty_list(opts))
  #     create_file(Path.join(migdir, "base.exs"), Templates.base_migration(opts))
  #     basemod = as_module("#{opts[:c_mod]}.Migrations")
  #
  #     if not File.exists?(@migrations_file) do
  #       create_file(@migrations_file, Templates.empty_list(opts))
  #     end
  #
  #     case Migration.Manage.add_include(@migrations_file, basemod) do
  #       {:exists, _prefix} ->
  #         IO.puts("""
  #
  #         Model already exists in `#{@migrations_file}`, not adding
  #
  #         """)
  #
  #       {:ok, mig} ->
  #         IO.puts("""
  #
  #         Model added to `#{@migrations_file}` with prefix `#{mig[:prefix]}`
  #
  #         """)
  #
  #       {:error, error} ->
  #         IO.puts(:stderr, error)
  #     end
  #   end
  # end
  #
  # defp configure_model({:error, reason}, _) do
  #   IO.puts(:stderr, reason)
  # end
  #
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
  # end
  #
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
