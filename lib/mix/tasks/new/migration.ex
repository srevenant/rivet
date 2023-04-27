defmodule Mix.Tasks.Rivet.New.Migration do
  import Rivet.Utils.Cli
  import Rivet.Utils.Cli.Print
  alias Rivet.Migration

  def run(optcfg, opts, [model, label]) do
    with {:ok, cfg} <- Mix.Tasks.Rivet.New.get_config(optcfg, opts),
         {:error, reason} <- Migration.Manage.add_migration(model, label, cfg),
         do: die(reason)
    :ok
  end

  def run(optcfg, _, _) do
    syntax(optcfg, "migration {model} {label}")
  end
end
