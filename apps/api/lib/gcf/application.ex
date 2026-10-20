defmodule Gcf.Application do
  use Application
  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:gcf, :serve, true) do
        [
          {Bandit,
           plug: Gcf.Router,
           scheme: :http,
           port: Application.get_env(:gcf, :port, 4000),
           ip: {0, 0, 0, 0}}
        ]
      else
        []
      end

    Supervisor.start_link([Gcf.Admin.LoginThrottle | children],
      strategy: :one_for_one,
      name: Gcf.Supervisor
    )
  end
end
