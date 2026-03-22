defmodule Browse.Pool do
  @moduledoc false
  @behaviour NimblePool

  alias Browse

  @impl NimblePool
  def init_pool(opts) do
    {implementation, opts} = Keyword.pop!(opts, :implementation)
    {:ok, %{implementation: implementation, browser_opts: opts, pool: Keyword.get(opts, :name)}}
  end

  @impl NimblePool
  def init_worker(%{implementation: implementation, browser_opts: browser_opts, pool: pool} = pool_state) do
    Browse.Telemetry.span(
      [:browse, :worker, :init],
      %{implementation: implementation, pool: pool},
      fn ->
        case implementation.init(browser_opts) do
          {:ok, state} ->
            {{:ok, %Browse{implementation: implementation, state: state}, pool_state},
             %{implementation: implementation, pool: pool}}

          {:error, reason} ->
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
end
