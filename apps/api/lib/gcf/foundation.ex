defmodule Gcf.Foundation do
  use Ash.Domain

  resources do
    resource(Gcf.Foundation.Status)
    resource(Gcf.Admin.Resource)
  end
end
