defmodule Browse do
  @moduledoc """
  Shared browser automation facade and pool implementation for browser backends.

  `Browse` defines a transport-agnostic API that packages such as `Chrona`
  or a future Servo implementation can use without exposing CDP or other
  backend-specific details to callers.

  ## Telemetry

  `Browse` emits telemetry for the pool lifecycle and browser operations:

  ### Pool lifecycle

  - `[:browse, :pool, :start, :start | :stop | :exception]`
  - `[:browse, :checkout, :start | :stop | :exception]`
  - `[:browse, :worker, :init, :start | :stop | :exception]`
  - `[:browse, :worker, :remove]`
  - `[:browse, :worker, :terminate]`

  ### Browser operations

  Each browser operation emits `:start`, `:stop`, and `:exception` events with
  `system_time` and `duration` measurements, plus an `:implementation` metadata key.

  - `[:browse, :navigate, ...]` — also includes `:url`
  - `[:browse, :current_url, ...]`
  - `[:browse, :content, ...]`
  - `[:browse, :evaluate, ...]`
  - `[:browse, :capture_screenshot, ...]`
  - `[:browse, :set_viewport, ...]` — also includes `:width`, `:height`
  - `[:browse, :print_to_pdf, ...]`
  - `[:browse, :click, ...]` — also includes `:locator`
  - `[:browse, :fill, ...]` — also includes `:locator`
  - `[:browse, :wait_for, ...]` — also includes `:locator`
  - `[:browse, :go_back, ...]`
  - `[:browse, :go_forward, ...]`
  - `[:browse, :reload, ...]`
  - `[:browse, :title, ...]`
  - `[:browse, :select_option, ...]` — also includes `:locator`
  - `[:browse, :hover, ...]` — also includes `:locator`
  - `[:browse, :get_text, ...]` — also includes `:locator`
  - `[:browse, :get_attribute, ...]` — also includes `:locator`, `:attribute`
  - `[:browse, :get_cookies, ...]`
  - `[:browse, :set_cookie, ...]`
  - `[:browse, :clear_cookies, ...]`

  See `Browse.Telemetry` for the event contract.

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
  alias Browse.Telemetry

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
    Telemetry.span([:browse, :navigate], %{implementation: implementation, url: url}, fn ->
      {implementation.navigate(state, url, opts), %{implementation: implementation, url: url}}
    end)
  end

  @spec current_url(browser()) :: {:ok, String.t()} | {:error, term()}
  def current_url(%__MODULE__{implementation: implementation, state: state}) do
    Telemetry.span([:browse, :current_url], %{implementation: implementation}, fn ->
      {implementation.current_url(state), %{implementation: implementation}}
    end)
  end

  @spec content(browser()) :: {:ok, String.t()} | {:error, term()}
  def content(%__MODULE__{implementation: implementation, state: state}) do
    Telemetry.span([:browse, :content], %{implementation: implementation}, fn ->
      {implementation.content(state), %{implementation: implementation}}
    end)
  end

  @spec evaluate(browser(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def evaluate(%__MODULE__{implementation: implementation, state: state}, script, opts \\ []) do
    Telemetry.span([:browse, :evaluate], %{implementation: implementation}, fn ->
      {implementation.evaluate(state, script, opts), %{implementation: implementation}}
    end)
  end

  @spec capture_screenshot(browser(), keyword()) :: {:ok, binary()} | {:error, term()}
  def capture_screenshot(%__MODULE__{implementation: implementation, state: state}, opts \\ []) do
    Telemetry.span([:browse, :capture_screenshot], %{implementation: implementation}, fn ->
      {implementation.capture_screenshot(state, opts), %{implementation: implementation}}
    end)
  end

  @spec set_viewport(browser(), pos_integer(), pos_integer(), keyword()) :: :ok | {:error, term()}
  def set_viewport(%__MODULE__{implementation: implementation, state: state}, width, height, opts \\ []) do
    Telemetry.span(
      [:browse, :set_viewport],
      %{implementation: implementation, width: width, height: height},
      fn ->
        {implementation.set_viewport(state, width, height, opts),
         %{implementation: implementation, width: width, height: height}}
      end
    )
  end

  @spec print_to_pdf(browser(), keyword()) :: {:ok, binary()} | {:error, term()}
  def print_to_pdf(%__MODULE__{implementation: implementation, state: state}, opts \\ []) do
    Telemetry.span([:browse, :print_to_pdf], %{implementation: implementation}, fn ->
      {implementation.print_to_pdf(state, opts), %{implementation: implementation}}
    end)
  end

  @spec click(browser(), locator(), keyword()) :: :ok | {:error, term()}
  def click(%__MODULE__{implementation: implementation, state: state}, locator, opts \\ []) do
    Telemetry.span([:browse, :click], %{implementation: implementation, locator: locator}, fn ->
      {implementation.click(state, locator, opts), %{implementation: implementation, locator: locator}}
    end)
  end

  @spec fill(browser(), locator(), String.t(), keyword()) :: :ok | {:error, term()}
  def fill(%__MODULE__{implementation: implementation, state: state}, locator, value, opts \\ []) do
    Telemetry.span([:browse, :fill], %{implementation: implementation, locator: locator}, fn ->
      {implementation.fill(state, locator, value, opts), %{implementation: implementation, locator: locator}}
    end)
  end

  @spec wait_for(browser(), locator(), keyword()) :: :ok | {:error, term()}
  def wait_for(%__MODULE__{implementation: implementation, state: state}, locator, opts \\ []) do
    Telemetry.span([:browse, :wait_for], %{implementation: implementation, locator: locator}, fn ->
      {implementation.wait_for(state, locator, opts), %{implementation: implementation, locator: locator}}
    end)
  end

  @spec go_back(browser(), keyword()) :: :ok | {:error, term()}
  def go_back(%__MODULE__{implementation: implementation, state: state}, opts \\ []) do
    Telemetry.span([:browse, :go_back], %{implementation: implementation}, fn ->
      {implementation.go_back(state, opts), %{implementation: implementation}}
    end)
  end

  @spec go_forward(browser(), keyword()) :: :ok | {:error, term()}
  def go_forward(%__MODULE__{implementation: implementation, state: state}, opts \\ []) do
    Telemetry.span([:browse, :go_forward], %{implementation: implementation}, fn ->
      {implementation.go_forward(state, opts), %{implementation: implementation}}
    end)
  end

  @spec reload(browser(), keyword()) :: :ok | {:error, term()}
  def reload(%__MODULE__{implementation: implementation, state: state}, opts \\ []) do
    Telemetry.span([:browse, :reload], %{implementation: implementation}, fn ->
      {implementation.reload(state, opts), %{implementation: implementation}}
    end)
  end

  @spec title(browser()) :: {:ok, String.t()} | {:error, term()}
  def title(%__MODULE__{implementation: implementation, state: state}) do
    Telemetry.span([:browse, :title], %{implementation: implementation}, fn ->
      {implementation.title(state), %{implementation: implementation}}
    end)
  end

  @spec select_option(browser(), locator(), String.t(), keyword()) :: :ok | {:error, term()}
  def select_option(%__MODULE__{implementation: implementation, state: state}, locator, value, opts \\ []) do
    Telemetry.span([:browse, :select_option], %{implementation: implementation, locator: locator}, fn ->
      {implementation.select_option(state, locator, value, opts), %{implementation: implementation, locator: locator}}
    end)
  end

  @spec hover(browser(), locator(), keyword()) :: :ok | {:error, term()}
  def hover(%__MODULE__{implementation: implementation, state: state}, locator, opts \\ []) do
    Telemetry.span([:browse, :hover], %{implementation: implementation, locator: locator}, fn ->
      {implementation.hover(state, locator, opts), %{implementation: implementation, locator: locator}}
    end)
  end

  @spec get_text(browser(), locator(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def get_text(%__MODULE__{implementation: implementation, state: state}, locator, opts \\ []) do
    Telemetry.span([:browse, :get_text], %{implementation: implementation, locator: locator}, fn ->
      {implementation.get_text(state, locator, opts), %{implementation: implementation, locator: locator}}
    end)
  end

  @spec get_attribute(browser(), locator(), String.t(), keyword()) :: {:ok, String.t() | nil} | {:error, term()}
  def get_attribute(%__MODULE__{implementation: implementation, state: state}, locator, name, opts \\ []) do
    Telemetry.span(
      [:browse, :get_attribute],
      %{implementation: implementation, locator: locator, attribute: name},
      fn ->
        {implementation.get_attribute(state, locator, name, opts),
         %{implementation: implementation, locator: locator, attribute: name}}
      end
    )
  end

  @spec get_cookies(browser(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def get_cookies(%__MODULE__{implementation: implementation, state: state}, opts \\ []) do
    Telemetry.span([:browse, :get_cookies], %{implementation: implementation}, fn ->
      {implementation.get_cookies(state, opts), %{implementation: implementation}}
    end)
  end

  @spec set_cookie(browser(), map(), keyword()) :: :ok | {:error, term()}
  def set_cookie(%__MODULE__{implementation: implementation, state: state}, cookie, opts \\ []) do
    Telemetry.span([:browse, :set_cookie], %{implementation: implementation}, fn ->
      {implementation.set_cookie(state, cookie, opts), %{implementation: implementation}}
    end)
  end

  @spec clear_cookies(browser(), keyword()) :: :ok | {:error, term()}
  def clear_cookies(%__MODULE__{implementation: implementation, state: state}, opts \\ []) do
    Telemetry.span([:browse, :clear_cookies], %{implementation: implementation}, fn ->
      {implementation.clear_cookies(state, opts), %{implementation: implementation}}
    end)
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

    Telemetry.span([:browse, :checkout], %{pool: pool, timeout: timeout}, fn ->
      result =
        NimblePool.checkout!(
          pool,
          :checkout,
          fn _from, browser ->
            normalize_checkout_result(fun.(browser))
          end,
          timeout
        )

      {result, %{pool: pool, timeout: timeout}}
    end)
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

    Telemetry.span([:browse, :pool, :start], %{pool: pool}, fn ->
      case NimblePool.start_link(pool_opts) do
        {:ok, pid} = result ->
          {result, %{implementation: implementation, pid: pid, pool: pool, pool_size: pool_size, result: :ok}}

        {:error, reason} = result ->
          {result,
           %{
             implementation: implementation,
             pool: pool,
             pool_size: pool_size,
             reason: reason,
             result: :error
           }}

        :ignore = result ->
          {result, %{implementation: implementation, pool: pool, pool_size: pool_size, result: :ignore}}
      end
    end)
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
