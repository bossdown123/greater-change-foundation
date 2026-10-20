defmodule Gcf.MixProject do
  use Mix.Project
  def project do
    [app: :gcf, version: "0.1.0", elixir: "~> 1.18", start_permanent: Mix.env() == :prod,
     deps: deps(), releases: [gcf: [include_executables_for: [:unix]]]]
  end
  def application, do: [extra_applications: [:logger], mod: {Gcf.Application, []}]
  defp deps do
    [{:ash, "~> 3.0"}, {:plug_cowboy, "~> 2.7"}, {:req, "~> 0.5"}, {:jason, "~> 1.4"}]
  end
end
