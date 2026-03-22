# Browse

[![Hex.pm](https://img.shields.io/hexpm/v/browse.svg)](https://hex.pm/packages/browse)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/browse)
[![CI](https://github.com/pepicrft/browse/actions/workflows/browse.yml/badge.svg)](https://github.com/pepicrft/browse/actions/workflows/browse.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Shared browser automation contract for Elixir browser implementations.

`Browse` defines a transport-agnostic contract for browser automation packages such as a Chrome implementation, a Servo implementation, or any future engine backend. The goal is to expose browser capabilities without leaking implementation details such as CDP sessions or engine-specific RPC handles.

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

`Browse` is not a browser engine and it does not speak a wire protocol itself, but it does define the shared pool lifecycle and browser capability contract that engine implementations provide.

It provides:

- `Browse.Browser` as the shared browser capability behavior
- `Browse.Pool` as the shared pool lifecycle behavior
- `Browse` as a facade that dispatches to an implementation module

This lets packages like `Chrona` and a future Servo implementation expose the same API while keeping CDP or any other backend protocol as an implementation detail.

## Example

```elixir
children = [
  Browse.child_spec(MyApp.Chrome, name: MyApp.ChromePool, pool_size: 4)
]
```

Or start a pool directly:

```elixir
{:ok, _pid} = Browse.start_link(MyApp.Chrome, name: MyApp.ChromePool, pool_size: 4)
```

Then use the pool through the unified API:

```elixir
Browse.checkout(MyApp.Chrome, MyApp.ChromePool, fn browser ->
  :ok = Browse.navigate(MyApp.Chrome, browser, "https://example.com")
  Browse.capture_screenshot(MyApp.Chrome, browser, format: "jpeg", quality: 90)
end)
```

## Behavior

Implementations are expected to satisfy two contracts:

- `Browse.Pool` for child specs, startup, and checkout
- `Browse.Browser` for browser capabilities such as navigation and screenshots

This keeps pool management as a `Browse` concern without mixing it into the browser capability behavior itself.

The browser handle passed around by the behavior is intentionally opaque. Each implementation is free to represent it however it needs.

## License

MIT License. See [LICENSE](LICENSE) for details.
