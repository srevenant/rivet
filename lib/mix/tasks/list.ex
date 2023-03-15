defmodule Mix.Tasks.Rivet.List do
  use Mix.Task
  import Rivet.Mix
  import Rivet.Migration
  import String, only: [slice: 2]
  require Logger

  # "Manage Rivet migrations"
  @shortdoc "list|ls|new|pending|commit|rollback [...args]"

  @impl true
  def run(["help"]), do: syntax()

  def run(args) do
    case parse_options(args, [archive: :boolean], a: :archive) do
      {opts, ["model"], _} -> list_models(opts)
      {opts, ["models"], _} -> list_models(opts)
      {opts, ["mig"], _} -> list_migrations(opts)
      {opts, ["migration"], _} -> list_migrations(opts)
      {opts, ["migrations"], _} -> list_migrations(opts)
      {_, _, []} -> syntax()
      {_, _, errs} -> syntax(inspect(errs, label: "bad arguments"))
    end
  end

  defp list_models(_opts), do: IO.puts("To be implemented")

  defp module_base(name) do
    case String.split("#{name}", ".") do
      list -> List.last(list)
    end
  end

  defp list_migrations(opts) do
    with {:ok, migs} <-
           Rivet.Migration.Load.prepare_project_migrations(opts, Mix.Project.config()) do
      migs = Enum.map(migs, fn mig ->
        Map.merge(mig, %{
          model: module_base(mig.model),
          module: module_base(mig.module)
        })
      end)

      model_x = maxlen_in(migs, & &1.model)
      module_x = maxlen_in(migs, & &1.model)

      IO.puts(
        "#{pad("PREFIX", 7, " ")} #{pad("VERSION", 14, " ")} #{pad("MODEL", model_x, " ")}  #{pad("MIGRATION", module_x, " ")} -> PATH"
      )

      Enum.each(migs, fn mig ->
        indent = if mig.base == true, do: "** ", else: "   "
        index = pad(mig.index, 18)
        pre = slice(index, 0..3)
        ver = slice(index, 4..-1)

        IO.puts(
          "#{indent}#{pre} #{ver} #{pad(mig.model, model_x, " ")}  #{pad(mig.module, module_x, " ")} -> #{mig.path}"
        )
      end)
    else
      {:error, msg} ->
        IO.puts(:stderr, msg)
    end
  end

  ################################################################################
  def syntax(err \\ false) do
    cmd = Rivet.Mix.task_cmd(__MODULE__)

    IO.puts(:stderr, """
    Availble Tasks:

       mix #{cmd} model|models
       mix #{cmd} mig|migrations

    Options:

      -a — when listing migrations, include archived migrations as well

    """)

    if err do
      IO.puts(:stderr, err)
    end
  end
end
