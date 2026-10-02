defmodule Rivet.Loader.Updates do
  require Logger

  def load_for(repo, opts) do
    defaults = [load_file_type: "Rivet.Data"]
    opts = Keyword.merge(defaults, opts)

    # this will throw an error if it doesn't exist, and that's fine
    Keyword.get(opts, :limits).release_app
    |> get_seeds()
    |> load_seeds(repo, opts, [])
  end

  def load_for_logged(repo, opts) do
    case load_for(repo, opts) do
      {:ok, logs} ->
        log_lines(logs)

      {:error, msg, logs} ->
        log_lines(logs)
        Logger.error(msg, type: "seed")
    end
  end

  defp log_lines(lines), do: Enum.each(lines, &Logger.info(&1, type: "seed"))

  defp load_seeds([seed | rest], repo, opts, logs) do
    with {:ok, logs} <- load_seed(seed, repo, opts, logs) do
      load_seeds(rest, repo, opts, logs)
    end
  end

  defp load_seeds([], _, _, logs), do: {:ok, Enum.reverse(logs)}

  ####
  defp load_seed(seed, repo, opts, logs) do
    with basename <- Path.basename(seed),
         [_, version] <- Regex.run(~r/^([0-9]+)/, basename),
         {:ok, xver} <- Transmogrify.As.as_int(version) do
      if need_to_load?(xver, repo) do
        with {:ok, %{log: log}} <- Rivet.Loader.load_file(seed, opts),
             {:ok, _} <- update_migrations_record(xver, repo) do
          {:ok, [normalize_logs(log) | logs]}
        else
          {:error, %{log: log}} ->
            {:error, "unable to continue", [normalize_logs(log) | logs]}
        end
      else
        {:ok, logs}
      end
    else
      _ ->
        {:error, "Invalid schemas version: #{seed}", logs}
    end
  end

  defp need_to_load?(xver, repo) do
    case repo.query("SELECT version from schema_migrations where version = $1", [xver]) do
      {:ok, %{rows: [[^xver]]}} -> false
      {:ok, %{rows: []}} -> true
    end
  end

  defp update_migrations_record(xver, repo) do
    repo.query(
      "INSERT into schema_migrations (version, inserted_at) values($1, $2)",
      [
        xver,
        NaiveDateTime.utc_now()
      ]
    )
  end

  # def write_logs(logs), do: normalize_logs(logs) |> Enum.each(&Logger.info(&1, type: "seed"))

  defp normalize_logs(iodata) do
    List.flatten(iodata)
    |> Enum.join("")
    |> String.split("\n")
    |> Enum.reject(fn x -> x == "" end)
    |> Enum.reverse()
  end

  @seeds_base "rivet/seeds/*"
  defp all_suffixed(base, suffix), do: Path.wildcard(base <> suffix)

  defp get_seeds(app) do
    base = Path.join(:code.priv_dir(String.to_atom(app)), @seeds_base)
    Enum.sort(all_suffixed(base, ".yml") ++ all_suffixed(base, ".yaml"))
  end
end
