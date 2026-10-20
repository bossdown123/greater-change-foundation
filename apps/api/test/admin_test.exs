defmodule Gcf.AdminTest do
  use ExUnit.Case, async: false
  import Plug.Test

  test "unconfigured admin APIs fail closed" do
    previous = Application.get_env(:gcf, :admin_password_hash)
    Application.put_env(:gcf, :admin_password_hash, "")
    on_exit(fn -> Application.put_env(:gcf, :admin_password_hash, previous) end)
    response = Gcf.Router.call(conn(:get, "/api/admin/events"), Gcf.Router.init([]))
    assert response.status == 503
  end

  test "the Ash content boundary rejects missing administrator actors" do
    result =
      Gcf.Admin.Resource
      |> Ash.ActionInput.for_action(:run, %{
        operation: "list",
        params: %{"collection" => "events"}
      })
      |> Ash.run_action()

    assert {:error, _} = result
  end

  test "image validation checks content rather than the supplied extension" do
    assert {:error, _} = Gcf.Admin.Content.image_type("<svg onload='bad'>")
    assert {:error, _} = Gcf.Admin.Content.image_type("not really a JPG")

    assert {:ok, "image/png", "png"} =
             Gcf.Admin.Content.image_type(<<137, 80, 78, 71, 13, 10, 26, 10, 0>>)
  end

  test "invalid event facts and money are rejected before persistence" do
    assert {:error, _} = Gcf.Admin.Content.validate("events", %{"title" => ""})

    assert {:error, _} =
             Gcf.Admin.Content.validate("events", %{"title" => "Event", "dates" => ["2026-02-30"]})

    assert {:error, _} =
             Gcf.Admin.Content.validate("events", %{"title" => "Event", "participants" => -1})

    assert {:error, _} =
             Gcf.Admin.Content.validate("events", %{
               "title" => "Event",
               "custom_fields" => [
                 %{"label" => "URL", "type" => "link", "value" => "javascript:alert(1)"}
               ]
             })
  end
end
