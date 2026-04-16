defmodule WCoreWeb.TelemetryIngestionController do
  use WCoreWeb, :controller

  alias WCore.Telemetry

  def create(conn, params) do
    Telemetry.ingest_heartbeat(%{
      node_id: params["node_id"],
      status: params["status"],
      payload: params["payload"] || %{},
      timestamp: params["timestamp"]
    })

    conn
    |> put_status(:accepted)
    |> json(%{status: "accepted"})
  rescue
    ArgumentError ->
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "invalid payload"})
  end
end
