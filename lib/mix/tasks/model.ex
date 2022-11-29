defmodule Mix.Tasks.Rivet.Model do
  use Mix.Task
  alias Rivet.Mix.Templates
  import Mix.Generator
  import Transmogrify
  require Logger
  import Rivet.Mix.Common

  @moduledoc """
  Generate a new Rivet Model structure
  """

  @switch_info [
    model: [default: true],
    db: [default: true],
    migration: [default: true],
    test: [default: true],
    loader: [default: false],
    seeds: [default: false],
    graphql: [default: false],
    resolver: [default: false],
    rest: [default: false],
    cache: [default: false]
  ]

  @defaults Enum.reduce(@switch_info, %{}, fn {k, opts}, acc ->
              if Keyword.has_key?(opts, :default) do
                Map.put(acc, k, opts[:default])
              else
                acc
              end
            end)
            |> Map.to_list()

  @switches [
    lib_dir: [:string, :keep],
    test_dir: [:string, :keep],
    # migration_prefix: [:integer, :keep],
    "app-base": [:string, :keep],
    order: [:integer, :keep],
    model: :boolean,
    db: :boolean,
    ab_cd: :boolean,
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
    d: :db,
    l: :loader,
    s: :seeds,
    g: :graphql,
    c: :cache,
    t: :test
  ]

  def run(args) do
    case OptionParser.parse(args, strict: @switches, aliases: @aliases) do
      {opts, [path_name], []} ->
        configure_model(Keyword.merge(@switch_info, opts), path_name)

      {_, _, errs} ->
        syntax()
        # TODO: better handle this
        IO.inspect(errs, label: "bad arguments")
    end
  end

  defp configure_model(opts, path_name) do
    %{
      uconf: uconf,
      app: app,
      moddir: moddir,
      testdir: testdir,
      base: base
    } = option_configs(opts)

    {mod, dir} = Path.split(path_name) |> List.pop_at(-1)

    moddir = Path.split(moddir)
    testdir = Path.split(testdir)

    table = pathname(mod)
    moddir = Path.join(moddir ++ ["#{app}"] ++ dir ++ [table])
    testdir = Path.join(testdir ++ ["#{app}"] ++ dir ++ [table])
    model = modulename(mod)
    # prefix our config opts with `c_` so they don't collide with command-line opts
    opts =
      Keyword.merge(opts,
        c_app: app,
        c_base: base,
        c_model: model,
        c_table: table,
        c_mod: "#{base}.#{model}"
      )

    dopts = Map.new(opts)

    create_directory(moddir)

    if dopts.model do
      create_file("#{moddir}/model.ex", Templates.model(opts))
    end

    if dopts.db do
      create_file("#{moddir}/db.ex", Templates.db(opts))
    end

    if dopts.loader do
      create_file("#{moddir}/loader.ex", Templates.empty(opts ++ [c_sub: "Loader"]))
    end

    if dopts.seeds do
      create_file("#{moddir}/seeds.ex", Templates.empty(opts ++ [c_sub: "Seeds"]))
    end

    if dopts.graphql do
      create_file("#{moddir}/graphql.ex", Templates.empty(opts ++ [c_sub: "Graphql"]))
    end

    if dopts.resolver do
      create_file("#{moddir}/resolver.ex", Templates.empty(opts ++ [c_sub: "Resolver"]))
    end

    if dopts.rest do
      create_file("#{moddir}/rest.ex", Templates.empty(opts ++ [c_sub: "Rest"]))
    end

    if dopts.cache do
      create_file("#{moddir}/cache.ex", Templates.empty(opts ++ [c_sub: "Cache"]))
    end

    if dopts.test do
      create_directory(testdir)
      create_file("#{testdir}/#{table}_test.ex", Templates.test(opts))
    end

    # note: keep this last for readability of the final message
    if dopts.migration do
      migdir = Path.join(moddir, "migrations")
      create_directory(migdir)
      create_file(Path.join(migdir, ".index.exs"), Templates.migrations(opts))
      create_file(Path.join(migdir, ".archive.exs"), Templates.empty_list(opts))
      create_file(Path.join(migdir, "base.exs"), Templates.base_migration(opts))
      migrations = ".migrations.exs"
      basemod = as_module("#{opts[:c_mod]}.Migrations")

      if not File.exists?(migrations) do
        create_file(migrations, Templates.empty_list(opts))
      end

      case Rivet.Mix.Migration.add_migration_include(migrations, basemod) do
        {:exists, prefix} ->
          IO.puts("""

          Model already exists in `#{migrations}`, not adding

          """)

        {:ok, mig} ->
          IO.puts("""

          Model added to `#{migrations}` with prefix `#{mig[:prefix]}`

          """)

        {:error, error} ->
          IO.puts(:stderr, error)
      end
    end
  end

  ################################################################################
  def summary(), do: "{path/to/module} [options]"

  def syntax(opts \\ nil) do
    cmd = Rivet.Mix.Common.task_cmd(__MODULE__)

    IO.puts(:stderr, """
    Syntax: mix #{cmd} {path/to/model_folder (singular)} [options]

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
    Enum.map(switches, fn {k, v} -> to_string(k) end)
    |> Enum.sort()
    |> list_options(Map.new(switches), aliases, Map.new(info))
  end

  def list_options([option | rest], switches, aliases, info) do
    key = String.to_atom(option)
    list_option(String.replace(option, "_", "-"), key, switches[key], aliases[key], info[key])
    list_options(rest, switches, aliases, info)
  end

  def list_options([], _, _, _), do: :ok

  def list_option(opt, optkey, :boolean, aliases, info) do
    {a, b} = if info[:default] == true, do: {"", "no-"}, else: {"no-", ""}
    # TODO: how does python list boolean defaults
    IO.puts(:stderr, "  --#{a}#{opt}|--#{b}#{opt}")
  end

  def list_option(opt, optkey, [type, :keep], alaises, info) do
    IO.puts(:stderr, "  --#{opt}=#{to_string(type) |> String.upcase()}")
  end
end
