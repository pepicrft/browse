defmodule Browse.Adapter do
  @moduledoc """
  Shared browser automation contract implemented by concrete engines.

  Adapters expose browser capabilities without leaking implementation details
  such as CDP, WebDriver BiDi, or engine-specific transport handles.
  """

  @type pool :: term()
  @type browser :: term()
  @type locator :: term()
  @type script :: String.t()
  @type url :: String.t()
  @type option_list :: keyword()
  @type result(value) :: {:ok, value} | {:error, term()}

  @callback child_spec(keyword()) :: Supervisor.child_spec()
  @callback start_link(keyword()) :: GenServer.on_start()
  @callback checkout(pool(), (browser() -> {term(), :ok | :remove}), keyword()) :: term()
  @callback navigate(browser(), url(), keyword()) :: :ok | {:error, term()}
  @callback current_url(browser()) :: result(url())
  @callback content(browser()) :: result(String.t())
  @callback evaluate(browser(), script(), keyword()) :: result(term())
  @callback capture_screenshot(browser(), keyword()) :: result(binary())
  @callback print_to_pdf(browser(), keyword()) :: result(binary())
  @callback click(browser(), locator(), keyword()) :: :ok | {:error, term()}
  @callback fill(browser(), locator(), String.t(), keyword()) :: :ok | {:error, term()}
  @callback wait_for(browser(), locator(), keyword()) :: :ok | {:error, term()}
end
