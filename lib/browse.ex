defmodule Browse do
  @moduledoc """
  Shared browser automation facade and pool implementation for browser backends.

  `Browse` defines a transport-agnostic API that packages such as `Chrona`
  or a future Servo implementation can use without exposing CDP or other
  backend-specific details to callers.

  ## Example

      config :browse,
        default_pool: MyApp.ChromePool,
        pools: [
          MyApp.ChromePool: [implementation: MyApp.Chrome, pool_size: 4]
        ]

      children = Browse.children()

      Browse.checkout(fn browser ->
        :ok = Browse.navigate(browser, "https://example.com")
        Browse.capture_screenshot(browser, format: "jpeg", quality: 90)
      end)
  """

  alias Browse.Browser
  alias Browse.Pool

  @type locator :: Browser.locator()
  @opaque browser :: %__MODULE__{implementation: module(), state: term()}

  @enforce_keys [:implementation, :state]
  defstruct [:implementation, :state]

  @spec children() :: [Supervisor.child_spec()]
  def children do
    configured_pools()
    |> Keyword.keys()
    |> Enum.map(&child_spec/1)
  end

  @spec child_spec(NimblePool.pool(), keyword()) :: Supervisor.child_spec()
  def child_spec(pool, opts \\ []) do
    pool_opts = pool_opts!(pool, opts)

    %{
      id: pool,
      start: {__MODULE__, :start_link, [pool, pool_opts]},
      type: :worker
    }
  end

  @spec start_link(NimblePool.pool(), keyword()) :: GenServer.on_start()
  def start_link(pool, opts \\ []) do
    pool_opts!(pool, opts)
    |> do_start_link(pool)
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

  @spec default_pool!() :: NimblePool.pool()
  def default_pool! do
    Application.fetch_env!(:browse, :default_pool)
  end

  defp do_start_link(opts, pool) do
    {pool_size, opts} = Keyword.pop(opts, :pool_size, 1)
    {implementation, opts} = Keyword.pop!(opts, :implementation)
    browser_opts = maybe_put_name(opts, pool)

    pool_opts =
      [
        worker: {Pool, Keyword.put(browser_opts, :implementation, implementation)},
        pool_size: pool_size
      ]
      |> maybe_put_name(pool)

    NimblePool.start_link(pool_opts)
  end

  defp pool_opts!(pool, opts) do
    configured_opts =
      configured_pools()
      |> Keyword.get(pool, [])

    merged_opts = Keyword.merge(configured_opts, opts)

    if Keyword.has_key?(merged_opts, :implementation) do
      merged_opts
    else
      raise ArgumentError, """
      missing browser implementation for pool #{inspect(pool)}

      Configure it with:

          config :browse,
            pools: [
              #{inspect(pool)}: [implementation: MyApp.Chrome]
            ]

      or pass `implementation: ...` when starting the pool.
      """
    end
  end

  defp configured_pools do
    Application.get_env(:browse, :pools, [])
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
