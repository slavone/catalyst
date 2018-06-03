defmodule Catalyst.Mixfile do
  use Mix.Project

  def project do
    [
      app: :catalyst,
      version: "0.3.0",
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
      extra_applications: [:hackney],
      env: [config: []]
    ]
  end

  defp applications(:test), do: [:cowboy, :plug, :tzdata]
  defp applications(_), do: []

  defp deps do
    [
      {:hackney, "~> 1.12.1"},
      {:ex_doc, "~> 0.14", only: :dev},
      {:exdav, "~> 0.0.1", only: [:dev, :test], git: "git@github.com:slavone/exdav.git", ref: "9ad26817" }
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
