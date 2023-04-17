defmodule Rivet.Migration.Manage do
  require Logger
  import Rivet.Migration
  import Rivet.Utils.Types, only: [as_int!: 1]
  alias Rivet.Cli.Templates
  import Mix.Generator
  import Transmogrify
  use Rivet

  @stepping 10
  @minimum 100
  @maximum 9999

  ##############################################################################
  def add_include(file, model) when is_binary(file) and is_atom(model) do
    with {migs, _} <- Code.eval_file(file),
         {:ok, next} <- get_highest_prefix(migs, {@minimum - @stepping, %{}}) do
      next = next + @stepping

      if next > @maximum do
        raise "Out of prefixes!"
      end

      mig = [include: model, prefix: next]

      migs =
        [mig | migs]
        |> Enum.sort(fn a, b -> Keyword.get(a, :prefix) >= Keyword.get(b, :prefix) end)

      with :ok <- File.write!(file, inspect(migs, pretty: true)) do
        {:ok, mig}
      end
    end
  end

  ##############################################################################
  def add_migration(model, label, cfg) do
    ver = (cfg.opts[:version] || datestamp()) |> as_int!()
    parts = module_parts(model, label, ver, cfg)

    cond do
      not File.exists?(parts.path.model) ->
        {:error, "Model not found `#{parts.name.model}` in `#{parts.path.model}`"}

      not File.exists?(parts.path.migrations) ->
        {:error,
         "Model Migrations not found `#{parts.name.migrations}` in `#{parts.path.migrations}`"}

      # TODO: figure out how it'llwork so we can put version in path, and check
      # if module exists by name, without version#. Code.module_exists() doesn't
      # work with .exs files...
      File.exists?(parts.path.migration) ->
        {:error,
         "Model Migration already exists `#{parts.name.migration}` in `#{parts.path.migration}`"}

      true ->
        create_migration(parts, cfg)
    end
  end

  ##############################################################################
  defp create_migration(parts, cfg) do
    mig =
      if cfg.opts[:base] == true do
        [base: true]
      else
        []
      end ++ [module: as_module(parts.base), version: parts.ver]

    opts =
      Map.take(cfg, [:app, :base, :base_path, :deps_path, :models_root, :tests_root])
      |> Map.merge(%{
        c_base: parts.name.model,
        c_name: parts.base,
        c_index: parts.ver
      })
      |> Map.to_list()

    create_file(parts.path.migration, Templates.migration(opts))
    index = Path.join(parts.path.migrations, ".index.exs")

    with {migs, _} <- Code.eval_file(index) do
      migs =
        [mig | migs]
        |> Enum.sort(fn a, b -> Keyword.get(a, :version) >= Keyword.get(b, :version) end)

      File.write!(index, inspect(migs, pretty: true))
    end
  end

  ##############################################################################
  defp module_parts(model, label, ver, cfg) do
    model_name =
      case String.split(modulename(model), ".") do
        [one] ->
          "#{cfg.base}.#{one}"

        [_ | _] = mod ->
          Enum.join(mod, ".")
      end

    base = modulename(label)
    migs_name = "#{model_name}.Migrations"
    mig_name = "#{migs_name}.#{base}"

    %{
      base: base,
      ver: ver,
      name: %{
        model: model_name,
        migrations: migs_name,
        migration: mig_name
      },
      path: %{
        model: "lib/" <> pathname(model_name),
        migrations: "lib/" <> pathname(migs_name),
        migration: "lib/#{pathname(mig_name)}.exs"
      }
    }
  end

  ##############################################################################
  defp get_include_prefix(%{prefix: p}, x, y) when is_number(p), do: {:ok, p, x, y}

  defp get_include_prefix(%{prefix: prefix}, x, y) when is_binary(prefix) do
    case Rivet.Utils.Types.as_int(prefix) do
      {:ok, num} -> {:ok, num, x, y}
      {:error, reason} -> {:error, "Invalid include prefix #{prefix}: #{reason}"}
    end
  end

  defp get_include_prefix(%{external: _, migrations: m}, last, hist) do
    with {:ok, p} <- get_highest_prefix(m, {last, hist}) do
      {:ok, p, last, hist}
    end
  end

  defp get_include_prefix(x, _, _),
    do: {:error, "Invalid or missing include prefix: #{inspect(Map.to_list(x))}"}

  ##############################################################################
  defp get_highest_prefix([mig | rest], {last, hist}) do
    dmig = Map.new(mig)

    with {:ok, prefix, last, hist} <- get_include_prefix(dmig, last, hist) do
      last = max(prefix, last)

      case {hist[prefix], hist[mig[:include]]} do
        {nil, nil} ->
          hist = Map.merge(hist, %{prefix => mig, mig[:include] => true})
          get_highest_prefix(rest, {last, hist})

        {_, true} ->
          {:exists, mig[:prefix]}

        {other, _} ->
          if other[:include] == mig[:include] do
            {:ok, prefix}
          else
            {:error, "Duplicate prefixes!\n  #{inspect(mig)}\n  #{inspect(other)}"}
          end
      end
    end
  end

  #  + @stepping}
  defp get_highest_prefix([], {last, _hist}), do: {:ok, last}
end
