defmodule WCore.Telemetry do
  @moduledoc """
  Telemetry domain context.
  """

  import Ecto.Query, warn: false

  alias WCore.Repo
  alias WCore.Telemetry.{Cache, Ingestor, Node, NodeMetric, WriteBehind}

  @status_topic "telemetry:status_changes"
  @valid_statuses ~w(ok warning fault unknown)

  def pubsub_topic, do: @status_topic

  def ingest_heartbeat(attrs) when is_map(attrs), do: Ingestor.ingest(attrs)

  def update_dashboard_metric(attrs) when is_map(attrs) do
    with {:ok, node_id} <- normalize_node_id(attrs[:node_id] || attrs["node_id"]),
         {:ok, total_events_processed} <-
           normalize_total_events(attrs[:total_events_processed] || attrs["total_events_processed"]),
         {:ok, payload} <- normalize_payload_input(attrs[:payload] || attrs["payload"]) do
      status = normalize_status(attrs[:status] || attrs["status"] || "unknown")

      last_seen_at =
        normalize_utc_datetime(attrs[:last_seen_at] || attrs["last_seen_at"]) || utc_now_usec()

      {snapshot, _status_changed?} =
        Cache.set_node(node_id, status, total_events_processed, payload, last_seen_at)

      WriteBehind.mark_dirty(node_id)

      {:ok, snapshot}
    end
  end

  def list_nodes do
    Repo.all(from n in Node, order_by: [asc: n.id])
  end

  def list_nodes_with_metrics do
    Repo.all(
      from n in Node,
        left_join: m in assoc(n, :metric),
        preload: [metric: m],
        order_by: [asc: n.id]
    )
  end

  def get_node!(id), do: Repo.get!(Node, id)

  def create_node(attrs) do
    %Node{}
    |> Node.changeset(attrs)
    |> Repo.insert()
  end

  def update_node(%Node{} = node, attrs) do
    node
    |> Node.changeset(attrs)
    |> Repo.update()
  end

  def delete_node(%Node{} = node), do: Repo.delete(node)

  def change_node(%Node{} = node, attrs \\ %{}), do: Node.changeset(node, attrs)

  def upsert_node_metrics([]), do: {:ok, 0}

  def upsert_node_metrics(entries) when is_list(entries) do
    now = utc_now_usec()

    rows =
      Enum.map(entries, fn entry ->
        %{
          node_id: entry.node_id,
          status: normalize_status(entry.status),
          total_events_processed: entry.total_events_processed,
          last_payload: entry.last_payload || %{},
          last_seen_at: normalize_utc_datetime(entry.last_seen_at),
          inserted_at: now,
          updated_at: now
        }
      end)

    try do
      {count, _} =
        Repo.insert_all(
          NodeMetric,
          rows,
          on_conflict:
            {:replace,
             [:status, :total_events_processed, :last_payload, :last_seen_at, :updated_at]},
          conflict_target: [:node_id]
        )

      {:ok, count}
    rescue
      error -> {:error, error}
    end
  end

  def dashboard_rows do
    hot_by_id = hot_metrics_by_id()

    list_nodes_with_metrics()
    |> Enum.map(fn node ->
      persisted = persisted_metric(node.metric)
      hot = Map.get(hot_by_id, node.id)

      merged =
        if hot do
          %{
            status: hot.status,
            total_events_processed: hot.event_count,
            last_payload: hot.last_payload,
            last_seen_at: hot.last_seen_at
          }
        else
          persisted
        end

      %{
        node_id: node.id,
        machine_identifier: node.machine_identifier,
        location: node.location,
        status: merged.status,
        total_events_processed: merged.total_events_processed,
        last_payload: merged.last_payload,
        last_seen_at: merged.last_seen_at
      }
    end)
  end

  def refresh_dashboard_rows(rows) do
    hot_by_id = hot_metrics_by_id()

    Enum.map(rows, fn row ->
      case Map.get(hot_by_id, row.node_id) do
        nil ->
          row

        hot ->
          %{
            row
            | status: hot.status,
              total_events_processed: hot.event_count,
              last_payload: hot.last_payload,
              last_seen_at: hot.last_seen_at
          }
      end
    end)
  end

  def status_totals(rows) do
    Enum.reduce(rows, %{ok: 0, warning: 0, fault: 0, unknown: 0}, fn row, acc ->
      case normalize_status(row.status) do
        "ok" -> Map.update!(acc, :ok, &(&1 + 1))
        "warning" -> Map.update!(acc, :warning, &(&1 + 1))
        "fault" -> Map.update!(acc, :fault, &(&1 + 1))
        _ -> Map.update!(acc, :unknown, &(&1 + 1))
      end
    end)
  end

  defp hot_metrics_by_id do
    Cache.list()
    |> Map.new(&{&1.node_id, &1})
  end

  defp persisted_metric(nil) do
    %{
      status: "unknown",
      total_events_processed: 0,
      last_payload: %{},
      last_seen_at: nil
    }
  end

  defp persisted_metric(metric) do
    %{
      status: metric.status,
      total_events_processed: metric.total_events_processed,
      last_payload: metric.last_payload || %{},
      last_seen_at: metric.last_seen_at
    }
  end

  defp normalize_status(status) when is_binary(status) do
    status
    |> String.trim()
    |> String.downcase()
    |> normalize_status_alias()
    |> then(fn normalized ->
      if normalized in @valid_statuses, do: normalized, else: "unknown"
    end)
  end

  defp normalize_status(status) when is_atom(status),
    do: status |> Atom.to_string() |> normalize_status()

  defp normalize_status_alias("atencao"), do: "warning"
  defp normalize_status_alias("atenção"), do: "warning"
  defp normalize_status_alias("falha"), do: "fault"
  defp normalize_status_alias("desconhecido"), do: "unknown"
  defp normalize_status_alias(status), do: status

  defp normalize_node_id(node_id) when is_integer(node_id), do: {:ok, node_id}

  defp normalize_node_id(node_id) when is_binary(node_id) do
    case Integer.parse(String.trim(node_id)) do
      {value, ""} -> {:ok, value}
      _ -> {:error, :invalid_node_id}
    end
  end

  defp normalize_node_id(_), do: {:error, :invalid_node_id}

  defp normalize_total_events(value) when is_integer(value) and value >= 0, do: {:ok, value}

  defp normalize_total_events(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed >= 0 -> {:ok, parsed}
      _ -> {:error, :invalid_total_events}
    end
  end

  defp normalize_total_events(_), do: {:error, :invalid_total_events}

  defp normalize_payload_input(payload) when is_map(payload), do: {:ok, payload}
  defp normalize_payload_input(nil), do: {:ok, %{}}

  defp normalize_payload_input(payload) when is_binary(payload) do
    payload = String.trim(payload)

    cond do
      payload == "" ->
        {:ok, %{}}

      true ->
        case Jason.decode(payload) do
          {:ok, parsed} when is_map(parsed) -> {:ok, parsed}
          _ -> {:error, :invalid_payload}
        end
    end
  end

  defp normalize_payload_input(_), do: {:error, :invalid_payload}

  defp utc_now_usec do
    DateTime.utc_now()
    |> normalize_utc_datetime()
  end

  defp normalize_utc_datetime(nil), do: nil

  defp normalize_utc_datetime(%DateTime{} = date_time) do
    date_time
    |> DateTime.to_unix(:microsecond)
    |> DateTime.from_unix!(:microsecond)
  end

  defp normalize_utc_datetime(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> normalize_utc_datetime()
  end

  defp normalize_utc_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, date_time, _offset} -> normalize_utc_datetime(date_time)
      _ -> nil
    end
  end

  defp normalize_utc_datetime(_), do: nil
end
