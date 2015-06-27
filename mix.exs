defmodule Harakiri.Mixfile do
  use Mix.Project

  def project do
    [app: :harakiri,
     version: "0.5.0",
     elixir: "~> 1.0.0",
     package: package,
     description: """
        Help applications do things to themselves.
      """]
  end

  def application do
    [mod: {Harakiri, []}]
  end

  defp package do
    [contributors: ["Rubén Caro"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/rubencaro/harakiri"}]
  end
end
