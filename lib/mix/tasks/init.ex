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

    cfg = config_build([], Mix.Project.config()[:app])

    with {:ok, mfile} <- Rivet.Config.clean_path([cfg.optsd.mig_dir, @migrations_file]) do
      create_file(mfile, Templates.empty_list([]))

      IO.puts("""

      Create your first model with:

         mix rivet.new model {name}
      """)
    end
  end

  # coveralls-ignore-stop
end
