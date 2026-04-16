defmodule WCoreWeb.TelemetryComponents do
  use WCoreWeb, :html

  attr :totals, :map, required: true

  def kpi_grid(assigns) do
    ~H"""
    <section class="kpi-grid">
      <.kpi_card label="Saudavel" value={@totals.ok} tone="ok" />
      <.kpi_card label="Atencao" value={@totals.warning} tone="warning" />
      <.kpi_card label="Falha" value={@totals.fault} tone="fault" />
      <.kpi_card label="Sem Sinal" value={@totals.unknown} tone="unknown" />
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :tone, :string, required: true

  defp kpi_card(assigns) do
    ~H"""
    <article class={["kpi-card", "kpi-#{@tone}"]}>
      <p><%= @label %></p>
      <strong><%= @value %></strong>
    </article>
    """
  end

  attr :filters, :map, required: true

  def filters_bar(assigns) do
    ~H"""
    <section class="filters-shell">
      <form phx-change="filter" class="filters-form">
        <div class="filter-control">
          <label for="query">Buscar node</label>
          <input
            id="query"
            name="filters[query]"
            type="text"
            value={@filters.query}
            placeholder="ID, maquina ou setor"
            autocomplete="off"
          />
        </div>

        <div class="filter-control">
          <label for="status">Status</label>
          <select id="status" name="filters[status]">
            <%= for {label, value} <- status_options() do %>
              <option value={value} selected={@filters.status == value}><%= label %></option>
            <% end %>
          </select>
        </div>
      </form>
    </section>
    """
  end

  attr :status, :string, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={["status-badge", status_class(@status)]}>
      <%= status_label(@status) %>
    </span>
    """
  end

  attr :rows, :list, required: true
  attr :status_options, :list, default: []

  def nodes_table(assigns) do
    ~H"""
    <section class="table-shell">
      <%= if @rows == [] do %>
        <div class="empty-state">
          <p class="empty-title">Nenhum node encontrado</p>
          <p class="empty-subtitle">Ajuste os filtros ou aguarde novos heartbeats.</p>
        </div>
      <% else %>
        <table class="nodes-table">
          <thead>
            <tr>
              <th>Node ID</th>
              <th>Maquina</th>
              <th>Setor</th>
              <th>Status</th>
              <th>Eventos</th>
              <th>Ultimo Pulso</th>
              <th>Payload</th>
            </tr>
          </thead>
          <tbody>
            <%= for row <- @rows do %>
              <tr>
                <td data-label="Node ID"><%= row.node_id %></td>
                <td data-label="Maquina"><%= row.machine_identifier %></td>
                <td data-label="Setor"><%= row.location %></td>
                <td data-label="Status">
                  <select
                    name="metric[status]"
                    class="inline-input inline-select"
                    form={"metric-form-#{row.node_id}"}
                  >
                    <%= for {label, value} <- @status_options do %>
                      <option value={value} selected={row.status == value}>{label}</option>
                    <% end %>
                  </select>
                </td>
                <td data-label="Eventos">
                  <input
                    type="number"
                    min="0"
                    step="1"
                    name="metric[total_events_processed]"
                    value={row.total_events_processed}
                    class="inline-input"
                    form={"metric-form-#{row.node_id}"}
                  />
                </td>
                <td data-label="Ultimo Pulso">
                  <input
                    type="datetime-local"
                    step="1"
                    name="metric[last_seen_at]"
                    value={to_datetime_local(row.last_seen_at)}
                    class="inline-input"
                    form={"metric-form-#{row.node_id}"}
                  />
                </td>
                <td data-label="Payload">
                  <form id={"metric-form-#{row.node_id}"} phx-submit="save_metric" class="inline-edit-form">
                    <input type="hidden" name="metric[node_id]" value={row.node_id} />
                    <textarea
                      name="metric[payload]"
                      rows="3"
                      class="inline-input inline-textarea"
                    ><%= payload_json(row.last_payload) %></textarea>
                    <button type="submit" class="btn btn-secondary inline-save-btn">Salvar</button>
                  </form>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </section>
    """
  end

  defp status_class("ok"), do: "status-ok"
  defp status_class("warning"), do: "status-warning"
  defp status_class("fault"), do: "status-fault"
  defp status_class(_), do: "status-unknown"

  defp status_options do
    [
      {"Todos", "all"},
      {"OK", "ok"},
      {"Atencao", "warning"},
      {"Falha", "fault"},
      {"Desconhecido", "unknown"}
    ]
  end

  defp status_label("ok"), do: "OK"
  defp status_label("warning"), do: "ATENCAO"
  defp status_label("fault"), do: "FALHA"
  defp status_label("unknown"), do: "DESCONHECIDO"
  defp status_label(status), do: String.upcase(status)

  defp payload_json(nil), do: "{}"

  defp payload_json(payload) when is_map(payload) do
    payload
    |> Jason.encode!(pretty: true)
  end

  defp payload_json(payload), do: inspect(payload)

  defp to_datetime_local(nil), do: ""

  defp to_datetime_local(%DateTime{} = date_time) do
    date_time
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_iso8601()
  end
end
