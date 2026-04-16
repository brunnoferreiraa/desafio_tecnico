defmodule WCore.Telemetry.Supervisor do
  @moduledoc """
  Supervises in-memory cache and write-behind pipeline.
  """

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      WCore.Telemetry.Cache,
      WCore.Telemetry.WriteBehind,
      WCore.Telemetry.Ingestor
    ]

    # If cache crashes we restart downstream workers to keep write-behind consistent.
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
