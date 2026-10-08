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
    app = Mix.Project.config()[:app]

    with {:ok, mfile} <-
           Rivet.Config.valid_file([app.optsd.mig_dir, @migrations_file], "migrations") do
      create_file(mfile, Templates.empty_list([]))

      IO.puts("""

      Create your first model with:

         mix rivet.new model {name}
      """)
    end
  end

  # coveralls-ignore-end
end
