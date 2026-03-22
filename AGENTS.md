# AGENTS

## Project

`browse` is a transport-agnostic browser automation contract for Elixir.

The package should stay focused on shared abstractions that multiple browser backends can implement, such as:

- browser capabilities via `Browse.Browser`
- pool lifecycle via `Browse.Pool`
- facade functions in `Browse`

The package should not absorb backend-specific protocol details such as CDP concepts, WebDriver BiDi handles, browser WebSocket URLs, or Chrome-only/Servo-only terminology into the public API.

## Architecture

- `Browse` is the public facade and dispatch layer.
- `Browse.Browser` defines browser capability callbacks.
- `Browse.Pool` defines pool startup and checkout callbacks.
- The browser handle is intentionally opaque and owned by each implementation.

When evolving the API, prefer capability-oriented names like `navigate`, `content`, `evaluate`, and `capture_screenshot` over transport-oriented names.

## Scope

Keep this repository focused on the shared contract and minimal package scaffolding.

- Shared interfaces, types, and docs belong here.
- Fake implementations for tests belong here.
- Concrete Chrome/Chrona or Servo implementation code does not belong here.

Release automation and packaging support can exist here, but they should stay minimal and should not drive the library design.

## Pull Requests

PR titles should follow the semantic commits convention, for example `feat: add browser capability contract` or `fix: adjust generated release notes`.

In docs and examples, refer to consumer implementation modules directly, such as `MyApp.Chrome`, rather than using the older `*Adapter` naming.
