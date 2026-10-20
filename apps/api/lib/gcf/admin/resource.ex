defmodule Gcf.Admin.Resource do
  use Ash.Resource, domain: Gcf.Foundation

  actions do
    action :run, :map do
      argument(:operation, :string, allow_nil?: false)
      argument(:params, :map, default: %{})

      run(fn input, context ->
        if context.actor == :gcf_admin do
          Gcf.Admin.Content.run(input.arguments.operation, input.arguments.params)
        else
          {:error, "Administrator access required"}
        end
      end)
    end
  end
end
