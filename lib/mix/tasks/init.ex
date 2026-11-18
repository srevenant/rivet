defmodule Mix.Tasks.Rivet.Init do
  use Mix.Task
  use Rivet
  alias Rivet.Cli.Templates
  import Mix.Generator

  @shortdoc "Initialize a Rivets project. For full syntax try: mix rivet help"

  @moduledoc @shortdoc

  @impl true
  # coveralls-ignore-start
  def run(_args) do
    Mix.Task.run("app.config", [])

    with {:ok, cfg} <- Rivet.Migration.Load.config_build([], Mix.Project.config()[:app]),
         :ok <- File.mkdir_p(cfg.optsd.mig_dir) do
      mfile = Rivet.Migration.Config.clean_path([cfg.optsd.mig_dir, @migrations_file])

      create_file(mfile, Templates.empty_list([]))

      IO.puts("""

      Create your first model with:

         mix rivet new model {name}
      """)
    else
      {:error, reason} -> Mix.raise("Rivet initialization failed: #{inspect(reason)}")
    end
  end

  # coveralls-ignore-stop
end
