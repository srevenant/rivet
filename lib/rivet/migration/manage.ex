defmodule Rivet.Migration.Manage do
  require Logger
  import Rivet.Migration
  import Mix.Generator
  import Transmogrify.As
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
        {:error, "Model Migrations not found in `#{parts.path.migrations}`"}

      # TODO: figure out how it'll work so we can put version in path, and check
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
      end ++ [version: parts.ver, module: parts.name.migration]

    opts =
      Map.take(cfg, [:app, :base, :base_path, :models_root, :tests_root])
      |> Map.merge(%{
        c_mod: parts.name.model,
        c_name: parts.base,
        c_index: parts.ver
      })
      |> Map.to_list()

    create_file(parts.path.migration, Rivet.Cli.Templates.migration(opts))
    index = Path.join(parts.path.migrations, @index_file)

    with {migs, _} <- Code.eval_file(index) do
      migs =
        [mig | migs]
        |> Enum.sort(fn a, b -> Keyword.get(a, :version) >= Keyword.get(b, :version) end)

      mig_alias = "#{parts.name.model}.Migrations"
      mig_code = inspect(migs, pretty: true) |> String.replace(mig_alias, "M")

      File.write!(index, "alias #{parts.name.model}.Migrations, as: M\n#{mig_code}")
    end
  end

  ##############################################################################
  @doc """
  iex> cfg = %{app: :rivet_email, base: "Rivet.Email", base_path: "../rivet_email", models_root: "../rivet_email/lib/email", opts: [base_dir: "../rivet_email"], tests_root: "../rivet_email/test/email"}
  iex> ver = 2000
  iex> module_parts("Template", "doctest", ver, cfg)
  %{base: "Doctest", name: %{migration: Rivet.Email.Template.Migrations.Doctest, model: "Rivet.Email.Template"}, path: %{migration: "priv/rivet/migrations/template/doctest.exs", migrations: "priv/rivet/migrations/template", model: "../rivet_email/lib/email/template"}, ver: 2000}
  """
  def module_parts(model, label, ver, cfg) do
    model_parts =
      case String.split(modulename(model), ".") do
        [one] ->
          Module.concat(cfg.base, one)

        [_ | _] = mod ->
          Module.concat(mod)
      end
      |> Module.split()

    model_path = model_parts |> List.last() |> pathname()
    model_name = Enum.join(model_parts, ".")

    base = modulename(label)
    mig_name = Module.concat([model_name, "Migrations", base])

    %{
      base: base,
      ver: ver,
      name: %{
        model: model_name,
        migration: mig_name
      },
      path: %{
        model: Path.join(cfg.models_root, model_path),
        migrations: "priv/rivet/migrations/#{model_path}",
        migration: "priv/rivet/migrations/#{model_path}/#{pathname(label)}.exs"
      }
    }
  end

  ##############################################################################
  defp get_include_prefix(%{prefix: p}, x, y) when is_number(p), do: {:ok, p, x, y}

  defp get_include_prefix(%{prefix: prefix}, x, y) when is_binary(prefix) do
    case Transmogrify.As.as_int(prefix) do
      {:ok, num} -> {:ok, num, x, y}
      :error -> {:error, "Invalid include prefix #{prefix}"}
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
