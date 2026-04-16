defmodule WCoreWeb.PlantDashboardLive do
  use WCoreWeb, :live_view

  alias WCore.Telemetry
  alias WCore.Telemetry.Node
  import WCoreWeb.TelemetryComponents

  @refresh_interval_ms 2_000
  @brasil_offset_seconds -3 * 60 * 60

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(WCore.PubSub, Telemetry.pubsub_topic())
      :timer.send_interval(@refresh_interval_ms, :refresh_hot_cache)
    end

    rows = Telemetry.dashboard_rows()
    filters = %{query: "", status: "all"}
    visible_rows = apply_filters(rows, filters)

    {:ok,
     socket
     |> assign(:page_title, "Planta 42 - Dashboard")
     |> assign(:all_rows, rows)
     |> assign(:rows, visible_rows)
     |> assign(:filters, filters)
     |> assign(:totals, Telemetry.status_totals(rows))
     |> assign(:visible_count, length(visible_rows))
     |> assign(:node_form, node_form())
     |> assign(:last_refresh_at, DateTime.utc_now())}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters_params}, socket) do
    filters = normalize_filters(filters_params)
    visible_rows = apply_filters(socket.assigns.all_rows, filters)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:rows, visible_rows)
     |> assign(:visible_count, length(visible_rows))}
  end

  @impl true
  def handle_event("validate_node", %{"node" => node_params}, socket) do
    changeset =
      %Node{}
      |> Telemetry.change_node(node_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :node_form, Phoenix.Component.to_form(changeset, as: :node))}
  end

  @impl true
  def handle_event("create_node", %{"node" => node_params}, socket) do
    case Telemetry.create_node(node_params) do
      {:ok, _node} ->
        all_rows = Telemetry.dashboard_rows()

        {:noreply,
         socket
         |> rebuild_dashboard_state(all_rows)
         |> assign(:node_form, node_form())
         |> put_flash(:info, "Maquina cadastrada com sucesso.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:node_form, Phoenix.Component.to_form(changeset, as: :node))
         |> put_flash(:error, "Nao foi possivel cadastrar a maquina.")}
    end
  end

  @impl true
  def handle_event("save_metric", %{"metric" => metric_params}, socket) do
    case Telemetry.update_dashboard_metric(metric_params) do
      {:ok, snapshot} ->
        all_rows = patch_row(socket.assigns.all_rows, snapshot)

        {:noreply,
         socket
         |> rebuild_dashboard_state(all_rows)
         |> put_flash(:info, "Metricas atualizadas com sucesso.")}

      {:error, :invalid_node_id} ->
        {:noreply, put_flash(socket, :error, "Node invalido para atualizacao.")}

      {:error, :invalid_total_events} ->
        {:noreply, put_flash(socket, :error, "Eventos deve ser um numero inteiro maior ou igual a 0.")}

      {:error, :invalid_payload} ->
        {:noreply, put_flash(socket, :error, "Payload invalido. Envie um JSON objeto valido.")}
    end
  end

  @impl true
  def handle_info(:refresh_hot_cache, socket) do
    all_rows = Telemetry.refresh_dashboard_rows(socket.assigns.all_rows)

    {:noreply, rebuild_dashboard_state(socket, all_rows)}
  end

  @impl true
  def handle_info({:status_changed, snapshot}, socket) do
    all_rows = patch_row(socket.assigns.all_rows, snapshot)

    {:noreply, rebuild_dashboard_state(socket, all_rows)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="dashboard-shell">
      <header class="dashboard-header">
        <div>
          <p class="dashboard-kicker">Tempo real + write-behind</p>
          <h2>Estado operacional dos edge devices</h2>
        </div>
        <div class="dashboard-meta">
          <p class="refresh-time">Atualizado: <%= format_time(@last_refresh_at) %></p>
          <p class="visible-count"><%= @visible_count %> de <%= length(@all_rows) %> nodes visiveis</p>
        </div>
      </header>

      <.kpi_grid totals={@totals} />
      <section class="register-node-shell">
        <div>
          <p class="register-node-kicker">Cadastro rapido</p>
          <h3>Adicionar nova maquina</h3>
        </div>

        <.form
          for={@node_form}
          phx-change="validate_node"
          phx-submit="create_node"
          class="register-node-form"
        >
          <.input
            field={@node_form[:machine_identifier]}
            label="Identificador da maquina"
            placeholder="P42-CNC-007"
            required
          />
          <.input
            field={@node_form[:location]}
            label="Localizacao"
            placeholder="Linha D / Inspecao"
            required
          />
          <.button type="submit" class="btn-primary">CRIAR</.button>
        </.form>
      </section>
      <.filters_bar filters={@filters} />
      <.nodes_table rows={@rows} status_options={editable_status_options()} />
    </section>
    """
  end

  defp patch_row(rows, snapshot) do
    {updated_rows, found?} =
      Enum.map_reduce(rows, false, fn row, found? ->
        if row.node_id == snapshot.node_id do
          updated =
            Map.merge(row, %{
              status: snapshot.status,
              total_events_processed: snapshot.event_count,
              last_payload: snapshot.last_payload,
              last_seen_at: snapshot.last_seen_at
            })

          {updated, true}
        else
          {row, found?}
        end
      end)

    if found?, do: updated_rows, else: Telemetry.dashboard_rows()
  end

  defp format_time(%DateTime{} = dt) do
    dt
    |> DateTime.add(@brasil_offset_seconds, :second)
    |> Calendar.strftime("%H:%M:%S BRT")
  end

  defp normalize_filters(params) do
    %{
      query: params["query"] |> to_string() |> String.trim(),
      status: normalize_status(params["status"])
    }
  end

  defp normalize_status(status) when status in ["all", "ok", "warning", "fault", "unknown"],
    do: status

  defp normalize_status(_), do: "all"

  defp editable_status_options do
    [
      {"OK", "ok"},
      {"ATENCAO", "warning"},
      {"FALHA", "fault"},
      {"DESCONHECIDO", "unknown"}
    ]
  end

  defp apply_filters(rows, %{query: query, status: status}) do
    query = String.downcase(query)

    rows
    |> Enum.filter(fn row ->
      status_match? = status == "all" or row.status == status
      query_match? = query == "" or row_matches_query?(row, query)
      status_match? and query_match?
    end)
  end

  defp row_matches_query?(row, query) do
    row.node_id
    |> Integer.to_string()
    |> String.contains?(query) or
      String.contains?(String.downcase(row.machine_identifier || ""), query) or
      String.contains?(String.downcase(row.location || ""), query)
  end

  defp node_form do
    Telemetry.change_node(%Node{})
    |> Phoenix.Component.to_form(as: :node)
  end

  defp rebuild_dashboard_state(socket, all_rows) do
    visible_rows = apply_filters(all_rows, socket.assigns.filters)

    socket
    |> assign(:all_rows, all_rows)
    |> assign(:rows, visible_rows)
    |> assign(:totals, Telemetry.status_totals(all_rows))
    |> assign(:visible_count, length(visible_rows))
    |> assign(:last_refresh_at, DateTime.utc_now())
  end
end
