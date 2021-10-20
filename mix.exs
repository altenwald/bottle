defmodule Bottle.MixProject do
  use Mix.Project

  def project do
    [
      app: :bottle,
      version: "0.2.1",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [
        main_module: Bottle,
        comment: "Bottle XMPP"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:exampple, "~> 0.9"},
      {:gen_state_machine, "~> 3.0"}
    ]
  end
end
