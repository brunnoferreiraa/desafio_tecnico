defmodule WCore.Telemetry.Ingestor do
  @moduledoc """
  Receives heartbeats and applies them to ETS with minimal latency.
  """

  use GenServer

  alias WCore.Telemetry
  alias WCore.Telemetry.Cache
  alias WCore.Telemetry.WriteBehind

  @valid_statuses ~w(ok warning fault unknown)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def ingest(attrs) when is_map(attrs) do
    node_id = attrs[:node_id] || attrs["node_id"]
    status = attrs[:status] || attrs["status"] || "unknown"
    payload = attrs[:payload] || attrs["payload"] || %{}
    timestamp = attrs[:timestamp] || attrs["timestamp"] || DateTime.utc_now()

    normalized = %{
      node_id: normalize_node_id(node_id),
      status: normalize_status(status),
      payload: normalize_payload(payload),
      timestamp: normalize_datetime(timestamp)
    }

    GenServer.cast(__MODULE__, {:ingest, normalized})
    :ok
  end

  @impl true
  def init(_opts) do
    {:ok, %{topic: Telemetry.pubsub_topic()}}
  end

  @impl true
  def handle_cast({:ingest, %{node_id: node_id} = event}, state) do
    {snapshot, status_changed?} =
      Cache.update_node(node_id, event.status, event.payload, event.timestamp)

    WriteBehind.mark_dirty(node_id)

    if status_changed? do
      Phoenix.PubSub.broadcast(WCore.PubSub, state.topic, {:status_changed, snapshot})
    end

    {:noreply, state}
  end

  defp normalize_node_id(node_id) when is_integer(node_id), do: node_id
  defp normalize_node_id(node_id) when is_binary(node_id), do: String.to_integer(node_id)

  defp normalize_status(status) when is_atom(status),
    do: status |> Atom.to_string() |> normalize_status()

  defp normalize_status(status) when is_binary(status) do
    status
    |> String.trim()
    |> String.downcase()
    |> normalize_status_alias()
    |> then(fn normalized ->
      if normalized in @valid_statuses, do: normalized, else: "unknown"
    end)
  end

  defp normalize_status_alias("atencao"), do: "warning"
  defp normalize_status_alias("atenção"), do: "warning"
  defp normalize_status_alias("falha"), do: "fault"
  defp normalize_status_alias("desconhecido"), do: "unknown"
  defp normalize_status_alias(status), do: status

  defp normalize_payload(payload) when is_map(payload), do: payload
  defp normalize_payload(payload), do: %{"raw" => inspect(payload)}

  defp normalize_datetime(%DateTime{} = date_time), do: to_utc_usec(date_time)

  defp normalize_datetime(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> to_utc_usec()
  end

  defp normalize_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, date_time, _offset} -> to_utc_usec(date_time)
      _ -> DateTime.utc_now() |> to_utc_usec()
    end
  end

  defp normalize_datetime(_), do: DateTime.utc_now() |> to_utc_usec()

  defp to_utc_usec(%DateTime{} = date_time) do
    date_time
    |> DateTime.to_unix(:microsecond)
    |> DateTime.from_unix!(:microsecond)
  end
end
