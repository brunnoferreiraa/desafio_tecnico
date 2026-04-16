defmodule WCore.Telemetry.WriteBehind do
  @moduledoc """
  Periodically flushes dirty ETS rows to SQLite in batches.
  """

  use GenServer
  require Logger

  alias WCore.Telemetry
  alias WCore.Telemetry.Cache

  @default_flush_interval_ms 2_000
  @default_flush_batch_size 500

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def mark_dirty(node_id) when is_integer(node_id) do
    GenServer.cast(__MODULE__, {:mark_dirty, node_id})
  end

  def flush_now do
    GenServer.call(__MODULE__, :flush_now, 60_000)
  end

  def pending_count do
    GenServer.call(__MODULE__, :pending_count)
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    state = %{
      dirty_nodes: MapSet.new(),
      flush_interval_ms: Keyword.get(opts, :flush_interval_ms, @default_flush_interval_ms),
      flush_batch_size: Keyword.get(opts, :flush_batch_size, @default_flush_batch_size),
      timer_ref: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:mark_dirty, node_id}, state) do
    dirty_nodes = MapSet.put(state.dirty_nodes, node_id)
    state = state |> Map.put(:dirty_nodes, dirty_nodes) |> schedule_flush()

    if MapSet.size(dirty_nodes) >= state.flush_batch_size do
      send(self(), :flush)
    end

    {:noreply, state}
  end

  @impl true
  def handle_call(:flush_now, _from, state) do
    {status, state} = flush_dirty(state)
    {:reply, status, state}
  end

  @impl true
  def handle_call(:pending_count, _from, state) do
    {:reply, MapSet.size(state.dirty_nodes), state}
  end

  @impl true
  def handle_info(:flush, state) do
    {_status, state} = flush_dirty(state)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    _ = flush_dirty(state)
    :ok
  end

  defp flush_dirty(state) do
    if MapSet.size(state.dirty_nodes) == 0 do
      {:ok, unschedule_flush(state)}
    else
      state = unschedule_flush(state)
      ids = MapSet.to_list(state.dirty_nodes)
      rows = Cache.get_many(ids)

      payload =
        Enum.map(rows, fn row ->
          %{
            node_id: row.node_id,
            status: row.status,
            total_events_processed: row.event_count,
            last_payload: row.last_payload,
            last_seen_at: row.last_seen_at
          }
        end)

      case Telemetry.upsert_node_metrics(payload) do
        {:ok, _count} ->
          {:ok, %{state | dirty_nodes: MapSet.new()}}

        {:error, reason} ->
          Logger.error("write-behind flush failed: #{inspect(reason)}")
          {:error, schedule_flush(state)}
      end
    end
  end

  defp schedule_flush(%{timer_ref: nil, flush_interval_ms: ms} = state) do
    %{state | timer_ref: Process.send_after(self(), :flush, ms)}
  end

  defp schedule_flush(state), do: state

  defp unschedule_flush(%{timer_ref: nil} = state), do: state

  defp unschedule_flush(%{timer_ref: timer_ref} = state) do
    Process.cancel_timer(timer_ref)
    %{state | timer_ref: nil}
  end
end
