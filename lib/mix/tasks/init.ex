defmodule Mix.Tasks.Rivet.Init do
  use Mix.Task
  use Rivet
  alias Rivet.Ecto.Templates
  import Mix.Generator

  @requirements ["app.config"]

  @shortdoc "Initialize a Rivets project. For full syntax try: mix rivet help"

  @moduledoc @shortdoc

  @impl true
  def run(_args) do
    app = Mix.Project.config()[:app]
    migrations_file = Application.app_dir(app, "priv/rivet/migrations") |> Path.join(@migrations_file)
    create_file(migrations_file, Templates.empty_list([]))

    IO.puts("""

    Create your first model with:

       mix rivet.new model {name}
    """)
  end
end
