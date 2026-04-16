defmodule WCore.Telemetry.Node do
  use Ecto.Schema
  import Ecto.Changeset

  schema "nodes" do
    field :machine_identifier, :string
    field :location, :string

    has_one :metric, WCore.Telemetry.NodeMetric

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(node, attrs) do
    node
    |> cast(attrs, [:machine_identifier, :location])
    |> validate_required([:machine_identifier, :location])
    |> validate_length(:machine_identifier, min: 3, max: 80)
    |> validate_length(:location, min: 3, max: 120)
    |> unique_constraint(:machine_identifier)
  end
end
