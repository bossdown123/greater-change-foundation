defmodule Gcf.Foundation do
  use Ash.Domain

  resources do
    resource(Gcf.Foundation.Status)
  end
end
