defmodule Harakiri.Mixfile do
  use Mix.Project

  def project do
    [app: :harakiri,
     version: "1.0.0",
     elixir: ">= 1.0.0",
     package: package,
     description: """
        Help applications do things to themselves.
      """]
  end

  def application do
    [mod: {Harakiri, []}]
  end

  defp package do
    [maintainers: ["Rubén Caro"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/rubencaro/harakiri"}]
  end
end
