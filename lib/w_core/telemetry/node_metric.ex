defmodule WCore.Telemetry.NodeMetric do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses ~w(ok warning fault unknown)

  schema "node_metrics" do
    field :status, :string, default: "unknown"
    field :total_events_processed, :integer, default: 0
    field :last_payload, :map
    field :last_seen_at, :utc_datetime_usec

    belongs_to :node, WCore.Telemetry.Node

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(metric, attrs) do
    metric
    |> cast(attrs, [:node_id, :status, :total_events_processed, :last_payload, :last_seen_at])
    |> validate_required([:node_id, :status, :total_events_processed])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:total_events_processed, greater_than_or_equal_to: 0)
    |> assoc_constraint(:node)
    |> unique_constraint(:node_id)
  end
end
