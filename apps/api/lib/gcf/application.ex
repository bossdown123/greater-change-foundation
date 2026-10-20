defmodule Gcf.Application do
  use Application
  @impl true
  def start(_type, _args) do
    children = if Application.get_env(:gcf, :serve, true) do
      [{Plug.Cowboy, scheme: :http, plug: Gcf.Router,
        options: [port: Application.get_env(:gcf, :port, 4000) , ip: {0, 0, 0, 0}]}]
    else
      []
    end
    Supervisor.start_link(children, strategy: :one_for_one, name: Gcf.Supervisor)
  end
end
