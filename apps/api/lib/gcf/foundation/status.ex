defmodule Gcf.Foundation.Status do
  use Ash.Resource, domain: Gcf.Foundation
  actions do
    action :readiness, :map do
      run fn _input, _context -> Gcf.Database.ready() end
    end
  end
end
