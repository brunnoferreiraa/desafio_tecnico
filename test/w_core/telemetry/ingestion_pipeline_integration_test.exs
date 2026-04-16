defmodule WCore.Telemetry.IngestionPipelineIntegrationTest do
  use WCore.DataCase, async: false

  alias WCore.Repo
  alias WCore.Telemetry
  alias WCore.Telemetry.{Cache, NodeMetric, WriteBehind}

  @event_count 10_000

  setup do
    Cache.reset!()
    _ = WriteBehind.flush_now()

    {:ok, node} =
      Telemetry.create_node(%{
        machine_identifier: "TEST-NODE-#{System.unique_integer([:positive])}",
        location: "Bancada de Stress"
      })

    %{node: node}
  end

  test "handles 10k concurrent events without losing count and syncs SQLite", %{node: node} do
    max_concurrency = System.schedulers_online() * 8

    1..(@event_count - 1)
    |> Task.async_stream(
      fn seq ->
        Telemetry.ingest_heartbeat(%{
          node_id: node.id,
          status: "ok",
          payload: %{"seq" => seq, "rpm" => 900 + rem(seq, 80)},
          timestamp: DateTime.utc_now()
        })
      end,
      max_concurrency: max_concurrency,
      ordered: false,
      timeout: 30_000
    )
    |> Enum.each(fn
      {:ok, :ok} -> :ok
      other -> flunk("unexpected task result: #{inspect(other)}")
    end)

    Telemetry.ingest_heartbeat(%{
      node_id: node.id,
      status: "fault",
      payload: %{"seq" => @event_count, "rpm" => 0, "alarm" => "overspeed_trip"},
      timestamp: DateTime.utc_now()
    })

    assert wait_until(
             fn ->
               case Cache.get(node.id) do
                 %{event_count: count, status: "fault"} when count == @event_count -> true
                 _ -> false
               end
             end,
             800,
             25
           )

    cache_row = Cache.get(node.id)
    assert cache_row.event_count == @event_count
    assert cache_row.status == "fault"

    assert :ok = WriteBehind.flush_now()

    db_row = Repo.get_by(NodeMetric, node_id: node.id)
    assert db_row.total_events_processed == @event_count
    assert db_row.status == "fault"
    assert db_row.last_payload["seq"] == @event_count
    assert WriteBehind.pending_count() == 0
  end

  defp wait_until(fun, retries, sleep_ms)

  defp wait_until(fun, retries, _sleep_ms) when retries <= 0 do
    fun.()
  end

  defp wait_until(fun, retries, sleep_ms) do
    if fun.() do
      true
    else
      Process.sleep(sleep_ms)
      wait_until(fun, retries - 1, sleep_ms)
    end
  end
end
