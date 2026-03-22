defmodule Browse do
  @moduledoc """
  Shared browser automation facade and pool implementation for browser backends.

  `Browse` defines a transport-agnostic API that packages such as `Chrona`
  or a future Servo implementation can use without exposing CDP or other
  backend-specific details to callers.

  ## Example

      config :browse, default_pool: MyApp.ChromePool

      children = [
        Browse.child_spec(MyApp.Chrome, name: MyApp.ChromePool, pool_size: 4)
      ]

      Browse.checkout(fn browser ->
        :ok = Browse.navigate(browser, "https://example.com")
        Browse.capture_screenshot(browser, format: "jpeg", quality: 90)
      end)
  """

  alias Browse.Browser

  @type locator :: Browser.locator()
  @opaque browser :: %__MODULE__{implementation: module(), state: term()}

  @enforce_keys [:implementation, :state]
  defstruct [:implementation, :state]

  defmodule Pool do
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

  @spec child_spec(module(), keyword()) :: Supervisor.child_spec()
  def child_spec(implementation, opts) do
    name = Keyword.fetch!(opts, :name)

    %{
      id: name,
      start: {__MODULE__, :start_link, [implementation, opts]},
      type: :worker
    }
  end

  @spec start_link(module(), keyword()) :: GenServer.on_start()
  def start_link(implementation, opts) do
    {pool_size, opts} = Keyword.pop(opts, :pool_size, 1)
    {name, opts} = Keyword.pop(opts, :name)
    browser_opts = maybe_put_name(opts, name)

    pool_opts =
      [
        worker: {Pool, Keyword.put(browser_opts, :implementation, implementation)},
        pool_size: pool_size
      ]
      |> maybe_put_name(name)

    NimblePool.start_link(pool_opts)
  end

  @spec checkout((browser() -> term()), keyword()) :: term()
  def checkout(fun, opts) when is_function(fun, 1) and is_list(opts) do
    checkout(default_pool!(), fun, opts)
  end

  @spec checkout((browser() -> term())) :: term()
  def checkout(fun) when is_function(fun, 1) do
    checkout(default_pool!(), fun, [])
  end

  @spec checkout(NimblePool.pool(), (browser() -> term()), keyword()) :: term()
  def checkout(pool, fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    NimblePool.checkout!(
      pool,
      :checkout,
      fn _from, browser ->
        normalize_checkout_result(fun.(browser))
      end,
      timeout
    )
  end

  @spec navigate(browser(), String.t(), keyword()) :: :ok | {:error, term()}
  def navigate(%__MODULE__{implementation: implementation, state: state}, url, opts \\ []) do
    implementation.navigate(state, url, opts)
  end

  @spec current_url(browser()) :: {:ok, String.t()} | {:error, term()}
  def current_url(%__MODULE__{implementation: implementation, state: state}) do
    implementation.current_url(state)
  end

  @spec content(browser()) :: {:ok, String.t()} | {:error, term()}
  def content(%__MODULE__{implementation: implementation, state: state}) do
    implementation.content(state)
  end

  @spec evaluate(browser(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def evaluate(%__MODULE__{implementation: implementation, state: state}, script, opts \\ []) do
    implementation.evaluate(state, script, opts)
  end

  @spec capture_screenshot(browser(), keyword()) :: {:ok, binary()} | {:error, term()}
  def capture_screenshot(%__MODULE__{implementation: implementation, state: state}, opts \\ []) do
    implementation.capture_screenshot(state, opts)
  end

  @spec print_to_pdf(browser(), keyword()) :: {:ok, binary()} | {:error, term()}
  def print_to_pdf(%__MODULE__{implementation: implementation, state: state}, opts \\ []) do
    implementation.print_to_pdf(state, opts)
  end

  @spec click(browser(), locator(), keyword()) :: :ok | {:error, term()}
  def click(%__MODULE__{implementation: implementation, state: state}, locator, opts \\ []) do
    implementation.click(state, locator, opts)
  end

  @spec fill(browser(), locator(), String.t(), keyword()) :: :ok | {:error, term()}
  def fill(%__MODULE__{implementation: implementation, state: state}, locator, value, opts \\ []) do
    implementation.fill(state, locator, value, opts)
  end

  @spec wait_for(browser(), locator(), keyword()) :: :ok | {:error, term()}
  def wait_for(%__MODULE__{implementation: implementation, state: state}, locator, opts \\ []) do
    implementation.wait_for(state, locator, opts)
  end

  @spec default_pool!() :: NimblePool.pool()
  def default_pool! do
    Application.fetch_env!(:browse, :default_pool)
  end

  defp normalize_checkout_result({result, status}) when status in [:ok, :remove] do
    {result, status}
  end

  defp normalize_checkout_result(result) do
    {result, :ok}
  end

  defp maybe_put_name(opts, nil), do: opts
  defp maybe_put_name(opts, name), do: Keyword.put(opts, :name, name)
end
