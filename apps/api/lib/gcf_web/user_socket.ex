defmodule GcfWeb.UserSocket do
  use Phoenix.Socket
  channel("admin:workspace", GcfWeb.WorkspaceChannel)

  def ticket(actor, expires) do
    Phoenix.Token.sign(GcfWeb.Endpoint, "admin socket", %{
      id: actor["id"],
      version: actor["session_version"],
      expires: expires
    })
  end

  @impl true
  def connect(%{"token" => token}, socket, _info)
      when is_binary(token) and byte_size(token) in 20..2048 do
    with {:ok, %{id: id, version: version, expires: expires}} <-
           Phoenix.Token.verify(GcfWeb.Endpoint, "admin socket", token, max_age: 120),
         true <- is_integer(expires) and expires > System.system_time(:second),
         actor when not is_nil(actor) <- Gcf.Admin.Accounts.session_actor(id, version) do
      {:ok, socket |> assign(:actor, actor) |> assign(:expires, expires)}
    else
      _ -> :error
    end
  end

  def connect(_, _, _), do: :error
  @impl true
  def id(socket), do: "admin_user:" <> socket.assigns.actor["id"]
end
