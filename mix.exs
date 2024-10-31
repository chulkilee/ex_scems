defmodule ExSCEMS.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_scems,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),

      # hex
      description: "Elixir wrapper for Sentinel Cloud EMS Web Services",

      # ex_doc
      name: "SCEMS",
      source_url: "https://github.com/chulkilee/ex_scems",
      homepage_url: "https://github.com/chulkilee/ex_scems",
      docs: [main: "ExSCEMS"],

      # test
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:tesla, "~> 0.10.0"},
      {:sweet_xml, "~> 0.6"},
      {:bypass, "~> 2.1", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.7", only: :test},
      {:ex_doc, "~> 0.16", only: :docs, runtime: false}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/chulkilee/ex_scems",
        "Changelog" => "https://github.com/chulkilee/ex_scems/blob/master/CHANGELOG.md"
      },
      maintainers: ["Chulki Lee"]
    ]
  end
end
