defmodule Browse.Pool do
  @moduledoc false
  @behaviour NimblePool

  alias Browse

  @initial_backoff_ms 50
  @max_backoff_ms 1_000
  @max_backoff_doublings 10

  # Consecutive launch failures, used to back off between attempts.
  #
  # This cannot live in `pool_state`: NimblePool discards the pool state a
  # failing `init_worker/1` was working with, so a failure has nowhere to record
  # itself. It lives in the process dictionary instead, which is sound here
  # because `init_worker/1` always runs in the pool process. It cannot run
  # anywhere else: returning `{:async, fun, pool_state}` would launch the
  # browser from a short-lived task, and implementations link the browser to
  # whoever launches it, so the browser would die with the task.
  @failures_key {__MODULE__, :consecutive_init_failures}

  @impl NimblePool
  def init_pool(opts) do
    {implementation, opts} = Keyword.pop!(opts, :implementation)
    {:ok, %{implementation: implementation, browser_opts: opts, pool: Keyword.get(opts, :name)}}
  end

  @impl NimblePool
  def init_worker(%{implementation: implementation, browser_opts: browser_opts, pool: pool} = pool_state) do
    # A failed launch is reported to NimblePool as a worker removal, which
    # schedules another one immediately. Without this the pool spins: a browser
    # that always fails is retried as fast as the pool process can loop.
    backoff_after_previous_failures()

    Browse.Telemetry.span(
      [:browse, :worker, :init],
      %{implementation: implementation, pool: pool},
      fn ->
        case implementation.init(browser_opts) do
          {:ok, state} ->
            Process.delete(@failures_key)

            {{:ok, %Browse{implementation: implementation, state: state}, pool_state},
             %{implementation: implementation, pool: pool}}

          {:error, reason} ->
            Process.put(@failures_key, Process.get(@failures_key, 0) + 1)
            raise "failed to initialize browser: #{inspect(reason)}"
        end
      end
    )
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, browser, pool_state) do
    {:ok, browser, browser, pool_state}
  end

  @impl NimblePool
  def handle_checkin(:ok, _from, browser, pool_state) do
    {:ok, browser, pool_state}
  end

  def handle_checkin(:remove, _from, _browser, %{implementation: implementation, pool: pool} = pool_state) do
    Browse.Telemetry.execute(
      [:browse, :worker, :remove],
      %{system_time: System.system_time()},
      %{implementation: implementation, pool: pool, reason: :checkout_remove}
    )

    {:remove, :closed, pool_state}
  end

  @impl NimblePool
  def terminate_worker(reason, %Browse{implementation: implementation, state: state}, %{pool: pool} = pool_state) do
    Browse.Telemetry.execute(
      [:browse, :worker, :terminate],
      %{system_time: System.system_time()},
      %{implementation: implementation, pool: pool, reason: reason}
    )

    :ok = implementation.terminate(reason, state)
    {:ok, pool_state}
  end

  defp backoff_after_previous_failures do
    case Process.get(@failures_key, 0) do
      0 -> :ok
      failures -> Process.sleep(backoff_ms(failures))
    end
  end

  defp backoff_ms(failures) do
    doublings = min(failures - 1, @max_backoff_doublings)

    min(@initial_backoff_ms * 2 ** doublings, @max_backoff_ms)
  end
end
