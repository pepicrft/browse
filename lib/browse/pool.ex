defmodule Browse.Pool do
  @moduledoc false
  @behaviour NimblePool

  alias Browse

  @impl NimblePool
  def init_pool(opts) do
    {implementation, opts} = Keyword.pop!(opts, :implementation)
    {:ok, %{implementation: implementation, browser_opts: opts}}
  end

  @impl NimblePool
  def init_worker(%{implementation: implementation, browser_opts: browser_opts} = pool_state) do
    case implementation.init(browser_opts) do
      {:ok, state} ->
        {:ok, %Browse{implementation: implementation, state: state}, pool_state}

      {:error, reason} ->
        raise "failed to initialize browser: #{inspect(reason)}"
    end
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, browser, pool_state) do
    {:ok, browser, browser, pool_state}
  end

  @impl NimblePool
  def handle_checkin(:ok, _from, browser, pool_state) do
    {:ok, browser, pool_state}
  end

  def handle_checkin(:remove, _from, _browser, pool_state) do
    {:remove, :closed, pool_state}
  end

  @impl NimblePool
  def terminate_worker(reason, %Browse{implementation: implementation, state: state}, pool_state) do
    :ok = implementation.terminate(reason, state)
    {:ok, pool_state}
  end
end
