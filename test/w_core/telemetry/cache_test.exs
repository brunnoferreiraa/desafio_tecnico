defmodule WCore.Telemetry.CacheTest do
  use WCore.DataCase, async: false

  alias WCore.Telemetry.Cache

  setup do
    Cache.reset!()
    :ok
  end

  test "stores latest heartbeat and increments counters atomically" do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second)

    {first, first_status_changed?} =
      Cache.update_node(101, "ok", %{"temperature" => 55.2}, timestamp)

    {second, second_status_changed?} =
      Cache.update_node(101, "fault", %{"temperature" => 93.5}, timestamp)

    assert first.event_count == 1
    assert first_status_changed?

    assert second.event_count == 2
    assert second.status == "fault"
    assert second_status_changed?
  end
end
