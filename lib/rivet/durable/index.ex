defmodule Supervisor.Durable do
  use Supervisor
  require Logger

  @backoff_default [0, 0, 5, 10, 30, 150, 300] |> Enum.map(&1 * 1000)
  @healthy_after_default :timer.minutes(10)

  def start_link(opts),
    do: Supervisor.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))

  @impl true
  def init(opts) do
    common = [
      backoff: Keyword.get(opts, :backoff, @backoff_default),
      healthy_after: Keyword.get(opts, :healthy_after, @healthy_after_default),
      # expect module to have a .report(a, b) pattern
      reporter: Keyword.get(opts, :reporter, __MODULE__)
    ]

    Keyword.fetch!(opts, :children)
    |> Enum.map(&{Rivet.Durable.Child, common ++ [spec: Supervisor.child_spec(&1, [])]})
    |> Supervisor.init(strategy: :one_for_one)
  end

  @spec report(msg :: String.t(), keyword()) :: {:error, msg :: String.t()}
  def report(a, b \\ []) do
    Logger.error(a, b)
    {:error, a}
  end
end
