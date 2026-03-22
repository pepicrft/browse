defmodule Browse.Browser do
  @moduledoc """
  Shared browser capability contract implemented by concrete engines.

  Implementations expose browser operations without leaking transport details
  such as CDP, WebDriver BiDi, or engine-specific RPC handles.
  """

  @type browser :: term()
  @type locator :: term()
  @type script :: String.t()
  @type url :: String.t()
  @type result(value) :: {:ok, value} | {:error, term()}

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
