defmodule DonutsServer.Mixfile do
  use Mix.Project

  def project do
    [app: :donuts_server,
     version: "0.0.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     dialyzer: [
       flags: ["-Werror_handling", "-Wrace_conditions", "-Wno_opaque", "-Wunderspecs"]
     ]
   ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:socket, "~> 0.3.4"},
      {:message_pack, "~> 0.2.0"},
      {:logger_file_backend, "~> 0.0.8"},
      {:dialyxir, "~> 0.3", only: [:test, :dev]},
      {:ex_doc, "~> 0.11", only: :dev},
    ]
  end
end
