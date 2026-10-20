defmodule GcfWeb.WorkspaceChannel do
  use Phoenix.Channel
  alias GcfWeb.Presence
  @sections ~w(events initiatives campaigns newsletters media history people account)
  @impl true
  def join("admin:workspace", _params, socket) do
    send(self(), :after_join)
    connection_id = Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
    {:ok, %{connection_id: connection_id}, assign(socket, :connection_id, connection_id)}
  end

  @impl true
  def handle_info(:after_join, socket) do
    Phoenix.PubSub.subscribe(Gcf.PubSub, "admin:changes")
    Presence.track(socket, socket.assigns.actor["id"], metadata(socket, %{}))
    push(socket, "presence_state", Presence.list(socket))
    Process.send_after(self(), :authorize, 30_000)
    {:noreply, socket}
  end

  def handle_info(:authorize, socket) do
    if valid?(socket) do
      Process.send_after(self(), :authorize, 30_000)
      {:noreply, socket}
    else
      push(socket, "revoked", %{})
      {:stop, :normal, socket}
    end
  end

  def handle_info({:changed, change}, socket) do
    if valid?(socket) do
      push(socket, "changed", change)
      {:noreply, socket}
    else
      push(socket, "revoked", %{})
      {:stop, :normal, socket}
    end
  end

  @impl true
  def handle_in("location", params, socket) do
    if valid?(socket) and params["section"] in @sections do
      Presence.update(socket, socket.assigns.actor["id"], metadata(socket, params))
      {:reply, :ok, socket}
    else
      {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  def handle_in("draft", params, socket) do
    allowed =
      ~w(title summary dates locations participants funds_raised currency custom_fields media_ids initiative_ids campaign_ids event_ids target raised starts_on ends_on subject introduction body updates alt caption)

    fields = params["fields"]

    valid =
      params["kind"] in ~w(events initiatives campaigns newsletters media) and
        is_binary(params["id"]) and Regex.match?(~r/^[a-f0-9]{32}$/, params["id"]) and
        is_map(fields) and map_size(fields) <= 30 and
        Enum.all?(Map.keys(fields), &(&1 in allowed)) and
        byte_size(Jason.encode!(fields)) <= 650_000

    if valid and valid?(socket) do
      actor = socket.assigns.actor

      broadcast_from!(socket, "draft", %{
        kind: params["kind"],
        id: params["id"],
        fields: fields,
        connection_id: socket.assigns.connection_id,
        actor_id: actor["id"],
        name: actor["name"]
      })

      {:reply, :ok, socket}
    else
      {:reply, {:error, %{reason: "invalid_draft"}}, socket}
    end
  end

  def handle_in(_, _, socket), do: {:reply, {:error, %{reason: "unsupported"}}, socket}

  defp valid?(socket) do
    actor = socket.assigns.actor

    socket.assigns.expires > System.system_time(:second) and
      Gcf.Admin.Accounts.session_actor(actor["id"], actor["session_version"]) != nil
  end

  defp metadata(socket, params) do
    actor = socket.assigns.actor

    %{
      connection_id: socket.assigns.connection_id,
      name: actor["name"],
      color: actor["color"],
      section: params["section"],
      resource_id: text(params["resource_id"], 64),
      title: text(params["title"], 120),
      field: text(params["field"], 200),
      interacted_at: System.system_time(:millisecond),
      editing: params["editing"] == true
    }
  end

  defp text(value, length) when is_binary(value), do: String.slice(value, 0, length)
  defp text(_, _), do: nil
end
