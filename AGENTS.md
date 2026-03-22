# AGENTS

## Project

`browse` is a transport-agnostic browser automation contract for Elixir.

The package should stay focused on shared abstractions that multiple browser backends can implement, such as:

- browser capabilities via `Browse.Browser`
- package-owned pool lifecycle via `Browse`
- facade functions in `Browse`

The package should not absorb backend-specific protocol details such as CDP concepts, WebDriver BiDi handles, browser WebSocket URLs, or Chrome-only/Servo-only terminology into the public API.

## Architecture

- `Browse` is the public facade and the actual pool implementation.
- `Browse.Browser` defines browser lifecycle and browser capability callbacks.
- `Browse` owns startup, checkout, and worker removal using package-provided infrastructure.
- `Browse` supports both explicit named pools and a configured default pool via `config :browse, default_pool: ...`.
- Browser implementations are configured per pool under `config :browse, pools: [...]`.
- The browser handle is intentionally opaque and wraps implementation state internally.

When evolving the API, prefer capability-oriented names like `navigate`, `content`, `evaluate`, and `capture_screenshot` over transport-oriented names.

## Scope

Keep this repository focused on the shared contract and minimal package scaffolding.

- Shared interfaces, types, and docs belong here.
- Fake implementations for tests belong here.
- Concrete Chrome/Chrona or Servo implementation code does not belong here.

Release automation and packaging support can exist here, but they should stay minimal and should not drive the library design.

## API Direction

Consumer code should read like browser automation, not transport wiring.

- Prefer `Browse.checkout(fn browser -> ... end)` when a default pool is configured.
- Keep explicit-pool APIs available for multi-pool scenarios.
- Do not require callers to pass implementation modules into browser operations.
- Do not introduce public APIs that expose CDP sessions, WebSocket URLs, or similar backend handles.

## Pull Requests

PR titles should follow the semantic commits convention, for example `feat: add browser capability contract` or `fix: adjust generated release notes`.

In docs and examples, refer to consumer implementation modules directly, such as `MyApp.Chrome`, rather than using the older `*Adapter` naming.
