defmodule WCore.Telemetry.Cache do
  @moduledoc """
  Fast in-memory telemetry state backed by ETS.
  """

  use GenServer

  @table :w_core_telemetry_cache

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def table, do: @table

  def update_node(node_id, status, payload, last_seen_at) when is_integer(node_id) do
    previous_status =
      case :ets.lookup(@table, node_id) do
        [{^node_id, old_status, _count, _payload, _timestamp}] -> old_status
        _ -> nil
      end

    count =
      :ets.update_counter(
        @table,
        node_id,
        {3, 1},
        {node_id, status, 0, payload, last_seen_at}
      )

    :ets.insert(@table, {node_id, status, count, payload, last_seen_at})

    snapshot = %{
      node_id: node_id,
      status: status,
      event_count: count,
      last_payload: payload,
      last_seen_at: last_seen_at
    }

    {snapshot, previous_status != status}
  end

  def set_node(node_id, status, event_count, payload, last_seen_at)
      when is_integer(node_id) and is_integer(event_count) and event_count >= 0 do
    previous_status =
      case :ets.lookup(@table, node_id) do
        [{^node_id, old_status, _count, _payload, _timestamp}] -> old_status
        _ -> nil
      end

    :ets.insert(@table, {node_id, status, event_count, payload, last_seen_at})

    snapshot = %{
      node_id: node_id,
      status: status,
      event_count: event_count,
      last_payload: payload,
      last_seen_at: last_seen_at
    }

    {snapshot, previous_status != status}
  end

  def get(node_id) when is_integer(node_id) do
    case :ets.lookup(@table, node_id) do
      [{^node_id, status, count, payload, timestamp}] ->
        %{
          node_id: node_id,
          status: status,
          event_count: count,
          last_payload: payload,
          last_seen_at: timestamp
        }

      _ ->
        nil
    end
  end

  def get_many(node_ids) when is_list(node_ids) do
    node_ids
    |> Enum.map(&get/1)
    |> Enum.reject(&is_nil/1)
  end

  def list do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {node_id, status, event_count, last_payload, last_seen_at} ->
      %{
        node_id: node_id,
        status: status,
        event_count: event_count,
        last_payload: last_payload,
        last_seen_at: last_seen_at
      }
    end)
    |> Enum.sort_by(& &1.node_id)
  end

  def reset! do
    :ets.delete_all_objects(@table)
    :ok
  end

  @impl true
  def init(_opts) do
    _table =
      :ets.new(@table, [
        :named_table,
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, %{}}
  end
end
