defmodule Browse.Telemetry do
  @moduledoc """
  Telemetry events emitted by `Browse`.

  `Browse` emits telemetry for the pool lifecycle, worker lifecycle, and
  individual browser operations. When called inside a `Browse.checkout/3`
  block, browser operation spans become child spans of the checkout span,
  giving consumers full request traces.

  ## Events

  ### `[:browse, :pool, :start, :start | :stop | :exception]`

  Emitted around `Browse.start_link/2`.

  Start metadata:

  - `:pool` - pool name

  Stop metadata:

  - `:pool` - pool name
  - `:implementation` - configured browser implementation module
  - `:pool_size` - configured pool size
  - `:result` - `:ok` or `:error`
  - `:pid` - started pool pid when available
  - `:reason` - error reason when startup fails

  Measurements:

  - `:system_time` on `:start`
  - `:duration` on `:stop` and `:exception`

  ### `[:browse, :checkout, :start | :stop | :exception]`

  Emitted around `Browse.checkout/3`.

  Metadata:

  - `:pool` - pool name
  - `:timeout` - checkout timeout in milliseconds

  Measurements:

  - `:system_time` on `:start`
  - `:duration` on `:stop` and `:exception`

  ### `[:browse, :worker, :init, :start | :stop | :exception]`

  Emitted around backend worker initialization in `Browse.Pool`.

  Metadata:

  - `:pool` - pool name
  - `:implementation` - browser implementation module

  Measurements:

  - `:system_time` on `:start`
  - `:duration` on `:stop` and `:exception`

  ### `[:browse, :worker, :remove]`

  Emitted when a checkout returns `{result, :remove}` and the worker is removed
  from the pool.

  Metadata:

  - `:pool` - pool name
  - `:implementation` - browser implementation module
  - `:reason` - always `:checkout_remove`

  Measurements:

  - `:system_time`

  ### `[:browse, :worker, :terminate]`

  Emitted when a worker is terminated and delegated to the configured browser
  implementation.

  Metadata:

  - `:pool` - pool name
  - `:implementation` - browser implementation module
  - `:reason` - worker termination reason

  Measurements:

  - `:system_time`

  ## Browser operation events

  Each browser operation emits `[:browse, <operation>, :start | :stop | :exception]`
  events via `:telemetry.span/3`.

  All operations include `:implementation` in metadata. Operations that accept a
  locator also include `:locator`. `navigate` includes `:url`, and `get_attribute`
  includes `:attribute`.

  Operations: `navigate`, `current_url`, `content`, `evaluate`,
  `capture_screenshot`, `print_to_pdf`, `click`, `fill`, `wait_for`, `go_back`,
  `go_forward`, `reload`, `title`, `select_option`, `hover`, `get_text`,
  `get_attribute`, `get_cookies`, `set_cookie`, `clear_cookies`.

  Measurements:

  - `:system_time` on `:start`
  - `:duration` on `:stop` and `:exception`

  ## Example

      events = [
        [:browse, :pool, :start, :stop],
        [:browse, :checkout, :stop],
        [:browse, :navigate, :stop],
        [:browse, :click, :stop],
        [:browse, :worker, :terminate]
      ]

      :telemetry.attach_many(
        "browse-metrics",
        events,
        &__MODULE__.handle_event/4,
        nil
      )

      def handle_event(event, measurements, metadata, _config) do
        IO.inspect({event, measurements, metadata}, label: "browse telemetry")
      end
  """

  @doc false
  def execute(event, measurements \\ %{}, metadata \\ %{}) do
    :telemetry.execute(event, measurements, metadata)
  end

  @doc false
  def span(event_prefix, metadata, fun) when is_function(fun, 0) do
    :telemetry.span(event_prefix, metadata, fun)
  end
end
