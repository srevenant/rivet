defmodule Mix.Tasks.Rivet do
  use Mix.Task

  @shortdoc "Rivet Framework. For full syntax try: mix rivet help"

  @moduledoc """
  Prints Rivet tasks and their information.

      Syntax: mix rivet help|{action}

  DONE:
      rivet init
      rivet n?ew model name
      rivet n?ew migration project name
      rivet l?ist|ls migration
      rivet m?igrate
      rivet help

  TODO:
      rivet list model
      rivet import
      rivet pending
      rivet rollback
  """
  @aliases %{
    "n" => "new",
    "ls" => "list",
    "l" => "list",
    "m" => "migrate"
  }

  @impl true
  # coveralls-ignore-start
  def run(args) do
    case args do
      [] ->
        list_commands()

      ["help"] ->
        list_commands()

      [cmd | args] ->
        cmd =
          case @aliases[cmd] do
            nil -> cmd
            cmd -> cmd
          end

        module = Module.safe_concat(__MODULE__, Macro.camelize(cmd))
        try do
          with_rivet_project(fn -> .run(args) end)
        rescue
          _ in ArgumentError ->
            list_commands()
            IO.puts(:stderr, "\nRivet command not found: `#{cmd}`\n")
        end
    end
  end

  defp list_commands() do
    Application.ensure_all_started(:rivet)
    Mix.shell().info("Rivet v#{Application.spec(:rivet, :vsn)}")
    Mix.shell().info("A toolkit for managing models in Elixir, working with Ecto.")
    Mix.shell().info(@moduledoc)
  end

  defp with_rivet_project(fun) do
    Mix.Task.run("app.config", [])

    case Mix.Project.apps_paths() do
      nil ->
        fun.()

      paths ->
        matches =
          for {app, path} <- paths,
              Application.ensure_loaded(app) == :ok,
              Application.get_env(app, :rivet) != nil,
              do: {app, path}

        case matches do
          [{app, path}] ->
            Mix.Project.in_project(app, path, fn _ -> fun.() end)

          [] ->
            Mix.raise("No umbrella application has Rivet configured")

          _ ->
            Mix.raise("Multiple Rivet applications found; run from a specific app")
        end
    end
  end

  # coveralls-ignore-stop
end
