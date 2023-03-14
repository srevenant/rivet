defmodule Mix.Tasks.Rivet.New do
  use Mix.Task
  alias Rivet.Mix.Templates
  import Mix.Generator
  import Transmogrify
  require Logger
  import Rivet.Mix
  import Rivet.Migration
  import Rivet.Migration.Manage
  use Rivet

  @shortdoc "Create a new Rivet Model or Model Migration"

  @moduledoc @shortdoc

  @switch_info [
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
  ]

  # @defaults Enum.reduce(@switch_info, %{}, fn {k, opts}, acc ->
  #             if Keyword.has_key?(opts, :default) do
  #               Map.put(acc, k, opts[:default])
  #             else
  #               acc
  #             end
  #           end)
  #           |> Map.to_list()

  @switches [
    # lib_dir: [:string, :keep],
    # mod_dir: [:string, :keep],
    # test_dir: [:string, :keep],
    # app_base: [:string, :keep],
    order: [:integer, :keep],
    # model: :boolean,
    lib: :boolean,
    migration: :boolean,
    loader: :boolean,
    seeds: :boolean,
    graphql: :boolean,
    resolver: :boolean,
    rest: :boolean,
    cache: :boolean,
    test: :boolean
  ]

  @aliases [
    m: :model,
    b: :lib,
    l: :loader,
    s: :seeds,
    g: :graphql,
    c: :cache,
    t: :test
  ]

  @impl true
  def run(args) do
    case parse_options(args, @switches, @aliases) do
      {opts, args, []} ->
        Keyword.merge(@switch_info, opts)
        |> Rivet.Config.build(Mix.Project.config())
        |> new(args)

      {_, _, errs} ->
        syntax()
        # TODO: better handle this
        IO.inspect(errs, label: "bad arguments")
    end
  end

  def new({:ok, cfg}, ["model", model_name]), do: configure_model(cfg, model_name)
  def new({:ok, cfg}, ["mig", model, label]), do: add_migration(model, label, cfg)
  def new({:ok, cfg}, ["migration", model, label]), do: add_migration(model, label, cfg)
  def new(_, _), do: syntax()

  defp configure_model(
         %{app: app, models_root: models_root, tests_root: tests_root, base: base} = cfg,
         path_name
       ) do
    alias = String.split(base, ".") |> List.last()
    mod = Path.split(path_name) |> List.last()

    modeldir = Path.join(models_root, path_name)
    testdir = Path.join(tests_root, path_name)
    model = modulename(path_name)
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
      migdir = Path.join(modeldir, "migrations")
      create_directory(migdir)
      create_file(Path.join(migdir, @index_file), Templates.migrations(opts))
      create_file(Path.join(migdir, @archive_file), Templates.empty_list(opts))
      create_file(Path.join(migdir, "base.exs"), Templates.base_migration(opts))
      basemod = as_module("#{opts[:c_mod]}.Migrations")

      if not File.exists?(@migrations_file) do
        create_file(@migrations_file, Templates.empty_list(opts))
      end

      case Rivet.Migration.Manage.add_migration_include(@migrations_file, basemod) do
        {:exists, _prefix} ->
          IO.puts("""

          Model already exists in `#{@migrations_file}`, not adding

          """)

        {:ok, mig} ->
          IO.puts("""

          Model added to `#{@migrations_file}` with prefix `#{mig[:prefix]}`

          """)

        {:error, error} ->
          IO.puts(:stderr, error)
      end
    end
  end

  defp configure_model({:error, reason}, _) do
    IO.puts(:stderr, reason)
  end

  ################################################################################
  def syntax(_opts \\ nil) do
    cmd = Rivet.Mix.task_cmd(__MODULE__)

    IO.puts(:stderr, """
    Syntax: mix #{cmd} model|mig|migration {path/to/model_folder (singular)} [options]

    Options:
    """)

    list_options(@switches, @aliases, @switch_info)
  end

  ## todo: bring in app defaults
  def list_options(switches, aliases, info \\ []) do
    # invert aliases
    aliases =
      Map.new(aliases)
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        Map.update(acc, v, [k], fn as -> [k | as] end)
      end)

    # switches as strings for sorting
    Enum.map(switches, fn {k, _} -> to_string(k) end)
    |> Enum.sort()
    |> list_options(Map.new(switches), aliases, Map.new(info))
  end

  def list_options([option | rest], switches, aliases, info) do
    key = String.to_atom(option)
    list_option(String.replace(option, "_", "-"), key, switches[key], aliases[key], info[key])
    list_options(rest, switches, aliases, info)
  end

  def list_options([], _, _, _), do: :ok

  def list_option(opt, _optkey, :boolean, _aliases, info) do
    {a, b} = if info[:default] == true, do: {"", "no-"}, else: {"no-", ""}
    # TODO: how does python list boolean defaults
    IO.puts(:stderr, "  --#{a}#{opt}|--#{b}#{opt}")
  end

  def list_option(opt, _optkey, [type, :keep], _aliases, _info) do
    IO.puts(:stderr, "  --#{opt}=#{to_string(type) |> String.upcase()}")
  end
end
