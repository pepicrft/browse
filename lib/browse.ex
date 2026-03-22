defmodule Browse do
  @moduledoc """
  Shared browser automation facade for renderer implementations.

  `Browse` defines a transport-agnostic API that packages such as `Chrona`
  or a future Servo adapter can implement without exposing CDP or other
  backend-specific details to callers.

  ## Example

      Browse.checkout(MyApp.ChromeAdapter, MyApp.ChromePool, fn browser ->
        :ok = Browse.navigate(MyApp.ChromeAdapter, browser, "https://example.com")
        Browse.capture_screenshot(MyApp.ChromeAdapter, browser, format: "jpeg", quality: 90)
      end)
  """

  alias Browse.Browser
  alias Browse.Pool

  @type implementation :: module()
  @type browser :: Browser.browser()
  @type pool :: Pool.pool()
  @type locator :: Browser.locator()

  @spec child_spec(implementation(), keyword()) :: Supervisor.child_spec()
  def child_spec(implementation, opts) do
    implementation.child_spec(opts)
  end

  @spec start_link(implementation(), keyword()) :: GenServer.on_start()
  def start_link(implementation, opts) do
    implementation.start_link(opts)
  end

  @spec checkout(implementation(), pool(), (browser() -> {term(), :ok | :remove}), keyword()) :: term()
  def checkout(implementation, pool, fun, opts \\ []) do
    implementation.checkout(pool, fun, opts)
  end

  @spec navigate(implementation(), browser(), String.t(), keyword()) :: :ok | {:error, term()}
  def navigate(implementation, browser, url, opts \\ []) do
    implementation.navigate(browser, url, opts)
  end

  @spec current_url(implementation(), browser()) :: {:ok, String.t()} | {:error, term()}
  def current_url(implementation, browser) do
    implementation.current_url(browser)
  end

  @spec content(implementation(), browser()) :: {:ok, String.t()} | {:error, term()}
  def content(implementation, browser) do
    implementation.content(browser)
  end

  @spec evaluate(implementation(), browser(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def evaluate(implementation, browser, script, opts \\ []) do
    implementation.evaluate(browser, script, opts)
  end

  @spec capture_screenshot(implementation(), browser(), keyword()) :: {:ok, binary()} | {:error, term()}
  def capture_screenshot(implementation, browser, opts \\ []) do
    implementation.capture_screenshot(browser, opts)
  end

  @spec print_to_pdf(implementation(), browser(), keyword()) :: {:ok, binary()} | {:error, term()}
  def print_to_pdf(implementation, browser, opts \\ []) do
    implementation.print_to_pdf(browser, opts)
  end

  @spec click(implementation(), browser(), locator(), keyword()) :: :ok | {:error, term()}
  def click(implementation, browser, locator, opts \\ []) do
    implementation.click(browser, locator, opts)
  end

  @spec fill(implementation(), browser(), locator(), String.t(), keyword()) :: :ok | {:error, term()}
  def fill(implementation, browser, locator, value, opts \\ []) do
    implementation.fill(browser, locator, value, opts)
  end

  @spec wait_for(implementation(), browser(), locator(), keyword()) :: :ok | {:error, term()}
  def wait_for(implementation, browser, locator, opts \\ []) do
    implementation.wait_for(browser, locator, opts)
  end
end
