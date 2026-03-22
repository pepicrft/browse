# Browse

[![Hex.pm](https://img.shields.io/hexpm/v/browse.svg)](https://hex.pm/packages/browse)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/browse)
[![CI](https://github.com/pepicrft/browse/actions/workflows/browse.yml/badge.svg)](https://github.com/pepicrft/browse/actions/workflows/browse.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Shared browser automation behavior for Elixir renderer adapters.

`Browse` defines a transport-agnostic contract for browser automation packages such as a Chrome adapter, a Servo adapter, or any future engine implementation. The goal is to expose browser capabilities without leaking implementation details such as CDP sessions or engine-specific RPC handles.

## Installation

Add `browse` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:browse, "~> 0.1.0"}
  ]
end
```

## Design

`Browse` is not a browser engine and it does not speak a wire protocol itself, but it does define the shared pool lifecycle and browser capability contract that engine adapters implement.

It provides:

- `Browse.Adapter` as the shared behavior implemented by concrete engines
- `Browse` as a small facade that dispatches to an adapter module
- a common way to start and supervise browser pools across engines

This lets packages like `Chrona` and a future Servo adapter implement the same API while keeping CDP or any other backend protocol as an implementation detail.

## Example

```elixir
children = [
  Browse.child_spec(MyApp.ChromeAdapter, name: MyApp.ChromePool, pool_size: 4)
]
```

Or start a pool directly:

```elixir
{:ok, _pid} = Browse.start_link(MyApp.ChromeAdapter, name: MyApp.ChromePool, pool_size: 4)
```

Then use the pool through the unified API:

```elixir
Browse.checkout(MyApp.ChromeAdapter, MyApp.ChromePool, fn browser ->
  :ok = Browse.navigate(MyApp.ChromeAdapter, browser, "https://example.com")
  Browse.capture_screenshot(MyApp.ChromeAdapter, browser, format: "jpeg", quality: 90)
end)
```

## Behavior

Adapters implementing `Browse.Adapter` are expected to provide:

- pool child specs and startup
- checkout
- navigation
- page content access
- script evaluation
- screenshot capture
- PDF rendering
- user-like interaction primitives such as click, fill, and wait

The browser handle passed around by the behavior is intentionally opaque. Each adapter is free to represent it however it needs.

## License

MIT License. See [LICENSE](LICENSE) for details.
