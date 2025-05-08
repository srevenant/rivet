defmodule Rivet.Migration do
  import Transmogrify
  require Logger
  use Rivet

  defstruct base: false,
            version: 0,
            index: nil,
            prefix: nil,
            parent: nil,
            model: nil,
            module: nil,
            path: nil,
            include: nil,
            external: nil,
            migrations: nil

  @type t :: %__MODULE__{
          base: boolean(),
          version: integer(),
          index: nil | String.t(),
          prefix: nil | integer(),
          parent: nil | module(),
          model: nil | module(),
          module: nil | module(),
          path: nil | String.t(),
          include: nil | module(),
          external: nil | String.t(),
          migrations: nil | list()
        }

  @doc """
  iex> datestamp(~N[2023-05-31 08:11:59])
  "20230531081159"
  iex> String.length(datestamp()) == 20
  """
  def datestamp(), do: NaiveDateTime.local_now() |> datestamp()
  def datestamp(time), do: Calendar.strftime(time, "%0Y%0m%0d%0H%0M%0S")

  @doc """
  iex> maxlen_in(["a", "bcde", "fgh", "xyzabcdef"])
  9
  """
  def maxlen_in(list, func \\ & &1),
    do: Enum.reduce(list, 0, fn i, x -> max(String.length(func.(i)), x) end)

  def as_module(name), do: Module.concat([modulename(name)])

  @doc """
  iex> module_extend(This.Module, Narf)
  This.Module.Narf
  """
  def module_extend(parent, mod), do: Module.concat(modulename(parent), modulename(mod))

  @doc """
  iex> module_pop(This.Module.Narf)
  This.Module
  """
  def module_pop(mod),
    do: Module.split(mod) |> List.delete_at(-1) |> Module.concat()

  @doc """
  iex> pad("x", 4)
  "000x"
  iex> pad("4", -4)
  "4000"
  iex> pad(4, -4)
  "4000"
  iex> pad(4, 4)
  "0004"
  """
  def pad(s, w, fill \\ "0")
  def pad(s, w, fill) when is_binary(s) and w < 0, do: String.pad_trailing(s, abs(w), fill)
  def pad(s, w, fill) when is_binary(s), do: String.pad_leading(s, w, fill)
  def pad(s, w, fill) when w < 0, do: String.pad_trailing("#{s}", abs(w), fill)
  def pad(s, w, fill), do: String.pad_leading("#{s}", w, fill)

  @doc """
  iex> migration_model(This.Narf.Migrations)
  "Narf"
  iex> migration_model(This.Narf.Not)
  "Not"
  """
  def migration_model(mod) do
    case Module.split(mod) |> Enum.reverse() do
      ["Migrations", model | _] -> model
      [model | _] -> model
    end
  end

  @doc """
  iex> nodot("this/narf/not.ex")
  ["this", "narf", "not.ex"]
  iex> nodot("./narf/not.ex")
  ["narf", "not.ex"]
  """
  def nodot(path) do
    case Path.split(path) do
      ["." | rest] -> rest
      rest -> rest
    end
  end

  @doc """
  iex> load_data_file("nar")
  {:error, "Cannot find file 'nar'"}
  iex> load_data_file("test/rivet_test_input")
  {:error, "Cannot load file 'test/rivet_test_input': Invalid contents"}

  # force an error
  iex> load_data_file("LICENSE.txt")
  {:error, "Cannot load file 'LICENSE.txt': keyword argument must be followed by space after: http:"}
  """
  @spec load_data_file(String.t()) :: {:ok, list(list())} | rivet_error()
  def load_data_file(path) do
    if File.exists?(path) do
      case Code.eval_file(path) do
        {opts, _} when is_list(opts) -> {:ok, opts}
        _ -> {:error, "Cannot load file '#{path}': Invalid contents"}
      end
    else
      {:error, "Cannot find file '#{path}'"}
    end
  rescue
    error in SyntaxError ->
      {:error, "Cannot load file '#{path}': #{error.description}"}
  end
end
