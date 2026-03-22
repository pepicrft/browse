defmodule Browse.Browser do
  @moduledoc """
  Shared browser capability contract implemented by concrete engines.

  Implementations expose browser operations without leaking transport details
  such as CDP, WebDriver BiDi, or engine-specific RPC handles.
  """

  @type state :: term()
  @type locator :: term()
  @type script :: String.t()
  @type url :: String.t()
  @type result(value) :: {:ok, value} | {:error, term()}

  @callback init(keyword()) :: {:ok, state()} | {:error, term()}
  @callback terminate(term(), state()) :: :ok
  @callback navigate(state(), url(), keyword()) :: :ok | {:error, term()}
  @callback current_url(state()) :: result(url())
  @callback content(state()) :: result(String.t())
  @callback evaluate(state(), script(), keyword()) :: result(term())
  @callback capture_screenshot(state(), keyword()) :: result(binary())
  @callback print_to_pdf(state(), keyword()) :: result(binary())
  @callback click(state(), locator(), keyword()) :: :ok | {:error, term()}
  @callback fill(state(), locator(), String.t(), keyword()) :: :ok | {:error, term()}
  @callback wait_for(state(), locator(), keyword()) :: :ok | {:error, term()}
end
