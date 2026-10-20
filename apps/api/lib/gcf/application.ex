defmodule Gcf.Application do
  use Application
  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:gcf, :serve, true) do
        case Gcf.Admin.Accounts.bootstrap() do
          {:error, _} -> raise "Unable to initialize administrator account"
          _ -> :ok
        end

        [
          GcfWeb.Endpoint
        ]
      else
        []
      end

    Supervisor.start_link(
      [{Phoenix.PubSub, name: Gcf.PubSub}, GcfWeb.Presence, Gcf.Admin.LoginThrottle | children],
      strategy: :one_for_one,
      name: Gcf.Supervisor
    )
  end
end
