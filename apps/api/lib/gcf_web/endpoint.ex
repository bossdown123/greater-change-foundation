defmodule GcfWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :gcf
  socket("/live", GcfWeb.UserSocket, websocket: true, longpoll: false)
  plug(Gcf.Router)
end
