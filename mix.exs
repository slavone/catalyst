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
      package: package(),
      source_url: "https://github.com/slavone/catalyst"
    ]
  end

  def application do
    [
      applications: applications(Mix.env),
      extra_applications: [:inets]
    ]
  end

  defp applications(:test), do: [:cowboy, :plug, :tzdata]
  defp applications(_), do: []

  defp deps do
    [
      {:ex_doc, "~> 0.14", only: :dev},
      {:exdav, "~> 0.0.1", only: [:dev, :test], git: "git@github.com:slavone/exdav.git", branch: "feature/use-this-for-tests" }
    ]
  end

  defp package do
    [
      maintainers: ["Slavone"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/slavone/catalyst"}
    ]
  end
end
