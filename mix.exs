defmodule Harakiri.Mixfile do
  use Mix.Project

  def project do
    [app: :harakiri,
     version: "0.2.0",
     elixir: "~> 1.0.0"]
  end

  def application do
    [mod: {Harakiri, []}]
  end
end
