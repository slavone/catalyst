defmodule Catalyst.Mixfile do
  use Mix.Project

  def project do
    [
      app: :catalyst,
      version: "0.1.0",
      elixir: "~> 1.4",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      description: "Elixir webdav client",
      package: package()
    ]
  end

  def application do
    [extra_applications: [:inets]]
  end

  defp deps do
    []
  end

  defp package do
    [
      maintainers: ["Slavone"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/slavone/catalyst"}
    ]
  end
end
