defmodule GcfWeb.WorkspaceChannel do
  use Phoenix.Channel
  alias GcfWeb.Presence
  @sections ~w(events initiatives campaigns newsletters media history people account)
  @impl true
  def join("admin:workspace", _params, socket) do
    send(self(), :after_join)
    {:ok, socket}
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

  def handle_in(_, _, socket), do: {:reply, {:error, %{reason: "unsupported"}}, socket}

  defp valid?(socket) do
    actor = socket.assigns.actor

    socket.assigns.expires > System.system_time(:second) and
      Gcf.Admin.Accounts.session_actor(actor["id"], actor["session_version"]) != nil
  end

  defp metadata(socket, params) do
    actor = socket.assigns.actor

    %{
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
