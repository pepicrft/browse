defmodule Browse do
  @moduledoc """
  Shared browser automation facade for renderer adapters.

  `Browse` defines a transport-agnostic API that packages such as `Chrona`
  or a future Servo adapter can implement without exposing CDP or other
  backend-specific details to callers.

  ## Example

      Browse.checkout(MyApp.ChromeAdapter, MyApp.ChromePool, fn browser ->
        :ok = Browse.navigate(MyApp.ChromeAdapter, browser, "https://example.com")
        Browse.capture_screenshot(MyApp.ChromeAdapter, browser, format: "jpeg", quality: 90)
      end)
  """

  alias Browse.Adapter

  @type adapter :: module()
  @type browser :: Adapter.browser()
  @type pool :: Adapter.pool()
  @type locator :: Adapter.locator()

  @spec child_spec(adapter(), keyword()) :: Supervisor.child_spec()
  def child_spec(adapter, opts) do
    adapter.child_spec(opts)
  end

  @spec start_link(adapter(), keyword()) :: GenServer.on_start()
  def start_link(adapter, opts) do
    adapter.start_link(opts)
  end

  @spec checkout(adapter(), pool(), (browser() -> {term(), :ok | :remove}), keyword()) :: term()
  def checkout(adapter, pool, fun, opts \\ []) do
    adapter.checkout(pool, fun, opts)
  end

  @spec navigate(adapter(), browser(), String.t(), keyword()) :: :ok | {:error, term()}
  def navigate(adapter, browser, url, opts \\ []) do
    adapter.navigate(browser, url, opts)
  end

  @spec current_url(adapter(), browser()) :: {:ok, String.t()} | {:error, term()}
  def current_url(adapter, browser) do
    adapter.current_url(browser)
  end

  @spec content(adapter(), browser()) :: {:ok, String.t()} | {:error, term()}
  def content(adapter, browser) do
    adapter.content(browser)
  end

  @spec evaluate(adapter(), browser(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def evaluate(adapter, browser, script, opts \\ []) do
    adapter.evaluate(browser, script, opts)
  end

  @spec capture_screenshot(adapter(), browser(), keyword()) :: {:ok, binary()} | {:error, term()}
  def capture_screenshot(adapter, browser, opts \\ []) do
    adapter.capture_screenshot(browser, opts)
  end

  @spec print_to_pdf(adapter(), browser(), keyword()) :: {:ok, binary()} | {:error, term()}
  def print_to_pdf(adapter, browser, opts \\ []) do
    adapter.print_to_pdf(browser, opts)
  end

  @spec click(adapter(), browser(), locator(), keyword()) :: :ok | {:error, term()}
  def click(adapter, browser, locator, opts \\ []) do
    adapter.click(browser, locator, opts)
  end

  @spec fill(adapter(), browser(), locator(), String.t(), keyword()) :: :ok | {:error, term()}
  def fill(adapter, browser, locator, value, opts \\ []) do
    adapter.fill(browser, locator, value, opts)
  end

  @spec wait_for(adapter(), browser(), locator(), keyword()) :: :ok | {:error, term()}
  def wait_for(adapter, browser, locator, opts \\ []) do
    adapter.wait_for(browser, locator, opts)
  end
end
