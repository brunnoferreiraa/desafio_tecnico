alias WCore.Repo
alias WCore.Telemetry.Node

nodes = [
  %{machine_identifier: "P42-CNC-001", location: "Linha A / Corte"},
  %{machine_identifier: "P42-CNC-002", location: "Linha A / Corte"},
  %{machine_identifier: "P42-ROBO-003", location: "Linha B / Solda"},
  %{machine_identifier: "P42-ROBO-004", location: "Linha B / Solda"},
  %{machine_identifier: "P42-PACK-005", location: "Linha C / Embalagem"},
  %{machine_identifier: "P42-PACK-006", location: "Linha C / Embalagem"}
]

for attrs <- nodes do
  Repo.insert!(
    %Node{}
    |> Node.changeset(attrs),
    on_conflict: :nothing,
    conflict_target: :machine_identifier
  )
end

