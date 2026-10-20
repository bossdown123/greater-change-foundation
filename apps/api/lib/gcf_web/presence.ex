defmodule GcfWeb.Presence do
  use Phoenix.Presence, otp_app: :gcf, pubsub_server: Gcf.PubSub
end
