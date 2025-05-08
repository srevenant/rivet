defmodule Mix.Tasks.Rivet.Migrate do
  use Mix.Task
  import Mix.Ecto

  @shortdoc "Commit Rivet Migrations. For full syntax try: mix rivet help"

  @moduledoc @shortdoc

  @switches [
    # all: :boolean,
    #    step: :integer,
    #    to: :integer,
    #    to_exclusive: :integer,
    quiet: :boolean,
    prefix: :string,
    pool_size: :integer,
    log_sql: :boolean,
    log_migrations_sql: :boolean,
    log_migrator_sql: :boolean,
    strict_version_order: :boolean,
    repo: [:keep, :string],
    no_compile: :boolean,
    no_deps_check: :boolean
    #    migrations_path: :keep
  ]

  @defaults [
    all: true,
    log: :info,
    log_migrations_sql: false,
    log_migrator_sql: false
  ]

  @doc """
  Notes/Options:

  1. call at the top level Mix.Tasks.Ecto.Migrate.run(), with a different
     Migrator as the second argument:

      https://github.com/elixir-ecto/ecto_sql/blob/v3.9.2/lib/mix/tasks/ecto.migrate.ex#L111

  2. clone the run command above and adjust it to suite (taking this option
     for now)

  """

  @impl true
  # derived from https://github.com/elixir-ecto/ecto_sql/blob/v3.9.2/lib/mix/tasks/ecto.migrate.ex#L111
  # coveralls-ignore-start
  def run(args) do
    Mix.Task.run("app.config", [])
    migrator = &Ecto.Migrator.run/4

    app =
      case Application.get_env(:rivet, :app) do
        nil ->
          Mix.raise("""
          Could not find app; is this run from an umbrella? Rivet migrate must run
          from within it's defined project. Try: mix cmd --app {app} mix rivet migrate
          """)

        pass ->
          pass
      end

    case Rivet.Migration.Load.prepare_project_migrations(args, app) do
      {:ok, rivet_migs} ->
        with {:ok, migs} <- Rivet.Migration.Load.to_ecto_migrations(rivet_migs) do
          repos = parse_repo(args)
          {opts, _} = OptionParser.parse!(args, strict: @switches, aliases: [])

          opts = Keyword.merge(@defaults, opts)

          {:ok, _} = Application.ensure_all_started(:ecto_sql)

          for repo <- repos do
            ensure_repo(repo, args)
            pool = repo.config()[:pool]

            fun =
              if Code.ensure_loaded?(pool) and function_exported?(pool, :unboxed_run, 2) do
                &pool.unboxed_run(&1, fn -> migrator.(&1, migs, :up, opts) end)
              else
                &migrator.(&1, migs, :up, opts)
              end

            case Ecto.Migrator.with_repo(repo, fun, [mode: :temporary] ++ opts) do
              {:ok, _migrated, _apps} ->
                :ok

              {:error, error} ->
                Mix.raise("Could not start repo #{inspect(repo)}, error: #{inspect(error)}")
            end
          end
        end

      {:error, msg} ->
        Mix.raise(msg)
    end
  end

  # coveralls-ignore-end
end
