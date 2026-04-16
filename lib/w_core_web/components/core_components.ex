defmodule WCoreWeb.CoreComponents do
  use Phoenix.Component
  use WCoreWeb, :verified_routes

  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group" class="flash-group">
      <%= for {kind, message} <- @flash, kind in [:info, :error], message not in [nil, ""] do %>
        <p class={["flash-message", "flash-#{kind}"]}><%= message %></p>
      <% end %>
    </div>
    """
  end

  attr :type, :string, default: "button"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button type={@type} class={["btn", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :type, :string, default: "text"
  attr :label, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :required, :boolean, default: false
  attr :rest, :global

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(:id, assigns[:id] || field.id)
      |> assign(:name, assigns[:name] || field.name)
      |> assign_new(:value, fn -> field.value end)
      |> assign(:errors, Enum.map(field.errors, &translate_error/1))

    ~H"""
    <div class="form-control">
      <%= if @label do %>
        <label for={@id}><%= @label %></label>
      <% end %>
      <input
        id={@id}
        name={@name}
        type={@type}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        placeholder={@placeholder}
        required={@required}
        class={["input", @errors != [] && "input-error"]}
        {@rest}
      />
      <%= for error <- @errors do %>
        <p class="form-error"><%= error %></p>
      <% end %>
    </div>
    """
  end

  defp translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(WCoreWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(WCoreWeb.Gettext, "errors", msg, opts)
    end
  end
end
