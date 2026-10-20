defmodule Gcf.RouterTest do
  use ExUnit.Case, async: false
  import Plug.Test

  test "HEAD requests use the same route without a response body" do
    response = Gcf.Router.call(conn(:head, "/healthz"), Gcf.Router.init([]))
    assert response.status == 200
    assert response.resp_body == ""
  end

  test "liveness works without database credentials" do
    response = Gcf.Router.call(conn(:get, "/healthz"), Gcf.Router.init([]))
    assert response.status == 200
    assert Jason.decode!(response.resp_body) == %{"status" => "ok"}
  end

  test "readiness fails closed when database is not configured" do
    previous = Application.get_env(:gcf, :turso_url)
    Application.delete_env(:gcf, :turso_url)
    on_exit(fn -> Application.put_env(:gcf, :turso_url, previous) end)
    response = Gcf.Router.call(conn(:get, "/readyz"), Gcf.Router.init([]))
    assert response.status == 503
    refute response.resp_body =~ "token"
  end

  test "unknown routes expose no application internals" do
    response = Gcf.Router.call(conn(:get, "/api/anything"), Gcf.Router.init([]))
    assert response.status == 404
    assert Jason.decode!(response.resp_body) == %{"error" => "not_found"}
  end
end
