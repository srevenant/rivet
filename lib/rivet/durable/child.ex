defmodule Supervisor.Durable.Child do
  use GenServer
  require Logger

  def child_spec(opts) do
    spec = Keyword.fetch!(opts, :spec)

    %{
      id: {__MODULE__, spec.id},
      start: {__MODULE__, :start_link, [opts]},

      # If *this wrapper* has a programming bug, normal OTP supervision applies.
      # A normal stop means its underlying child's restart policy said not to restart.
      restart: :transient,
      shutdown: spec.shutdown,
      type: :worker
    }
  end

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  ##############################################################################
  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    state = %{
      spec: Keyword.fetch!(opts, :spec),
      backoff: Keyword.fetch!(opts, :backoff),
      healthy_after: Keyword.fetch!(opts, :healthy_after),
      reporter: Keyword.fetch!(opts, :reporter),
      child: nil,
      started_at: nil,
      failures: 0
    }

    {:ok, start_child(state)}
  end

  ##############################################################################
  @impl true
  def handle_info(:restart, state), do: {:noreply, start_child(state)}

  def handle_info({:EXIT, pid, reason}, %{child: pid} = state) do
    if restart?(state.spec.restart, reason) do
      {:noreply, failed(state, reason)}
    else
      {:stop, :normal, %{state | child: nil}}
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  ##############################################################################
  defp start_child(state) do
    case safe_start(state.spec.start) do
      {:ok, pid} -> %{state | child: pid, started_at: now()}
      :ignore -> %{state | child: nil, started_at: nil}
      {:error, reason} -> failed(state, {:start_failed, reason})
    end
  end

  ##############################################################################
  defp failed(state, reason) do
    uptime =
      if state.started_at,
        do: now() - state.started_at,
        else: 0

    failures =
      if uptime >= state.healthy_after,
        do: 1,
        else: state.failures + 1

    delay = Enum.at(state.backoff, failures - 1, List.last(state.backoff))

    report(state, reason, failures, uptime, delay)

    Process.send_after(self(), :restart, delay)

    %{state | child: nil, started_at: nil, failures: failures}
  end

  ##############################################################################
  defp safe_start({mod, fun, args}) do
    try do
      case apply(mod, fun, args) do
        {:ok, pid} -> {:ok, pid}
        {:ok, pid, _} -> {:ok, pid}
        :ignore -> :ignore
        {:error, _} = error -> error
        other -> {:error, {:unexpected_start_result, other}}
      end
    rescue
      error -> {:error, {error, __STACKTRACE__}}
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  ##############################################################################
  defp restart?(:permanent, _), do: true

  defp restart?(:transient, reason),
    do: reason not in [:normal, :shutdown] and not match?({:shutdown, _}, reason)

  defp restart?(:temporary, _), do: false

  ##############################################################################
  defp report(state, reason, failures, uptime, delay) do
    opts = [
      child: state.spec.id,
      reason: inspect(reason),
      failures: failures,
      uptime_ms: uptime,
      restart_in_ms: delay
    ]

    try do
      state.reporter.report("Durable process crashed", opts)
    rescue
      _ -> Logger.error("Durable process crashed", opts)
    catch
      _, _ -> Logger.error("Durable process crashed", opts)
    end
  end

  defp now(), do: System.monotonic_time(:millisecond)
end
