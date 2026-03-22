defmodule Browse.Pool do
  @moduledoc """
  Shared pool lifecycle contract implemented by concrete engines.

  `Browse` owns the supervision and checkout shape, while engine packages
  provide the concrete pool implementation behind this behavior.
  """

  @type pool :: term()
  @type browser :: term()

  @callback child_spec(keyword()) :: Supervisor.child_spec()
  @callback start_link(keyword()) :: GenServer.on_start()
  @callback checkout(pool(), (browser() -> {term(), :ok | :remove}), keyword()) :: term()
end
