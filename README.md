# Browse

[![Hex.pm](https://img.shields.io/hexpm/v/browse.svg)](https://hex.pm/packages/browse)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/browse)
[![CI](https://github.com/pepicrft/browse/actions/workflows/browse.yml/badge.svg)](https://github.com/pepicrft/browse/actions/workflows/browse.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Shared browser automation contract and pool implementation for Elixir browser backends.

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

`Browse` is not a browser engine and it does not speak a wire protocol itself, but it does provide the shared pool implementation and browser capability contract that engine backends plug into.

It provides:

- `Browse.Browser` as the shared browser capability behavior
- `Browse` as the actual pool implementation and facade

This lets packages like `Chrona` and a future Servo implementation expose the same API while keeping CDP or any other backend protocol as an implementation detail.

## Example

Configure your pools and the default pool:

```elixir
config :browse,
  default_pool: MyApp.ChromePool,
  pools: [
    MyApp.ChromePool: [implementation: MyApp.Chrome, pool_size: 4],
    MyApp.SecondaryChromePool: [implementation: MyApp.Chrome, pool_size: 2]
  ]
```

Start the configured pools under your application supervisor:

```elixir
children = Browse.children()
```

Or start one configured pool directly:

```elixir
{:ok, _pid} = Browse.start_link(MyApp.ChromePool)
```

Then use the pool through the unified API:

```elixir
Browse.checkout(fn browser ->
  :ok = Browse.navigate(browser, "https://example.com")
  Browse.capture_screenshot(browser, format: "jpeg", quality: 90)
end)
```

If you have multiple pools, you can still target one explicitly:

```elixir
Browse.checkout(MyApp.SecondaryChromePool, fn browser ->
  Browse.current_url(browser)
end)
```

You can also override config at startup time if needed:

```elixir
{:ok, _pid} =
  Browse.start_link(MyApp.ChromePool,
    implementation: MyApp.Chrome,
    pool_size: 1
  )
```

## Behavior

Implementations are expected to satisfy `Browse.Browser`.

`Browse` owns pool startup, checkout, and worker lifecycle. Implementations are configured per pool and only provide browser initialization, termination, and browser operations such as navigation and screenshots.

Pooling is not a behavior. It is a concrete concern of this package, implemented by `Browse` itself. Backends plug into that runtime by implementing `Browse.Browser`.

The browser handle passed around by the behavior is intentionally opaque. Each implementation is free to represent it however it needs.

## License

MIT License. See [LICENSE](LICENSE) for details.
