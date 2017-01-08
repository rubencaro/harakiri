defmodule Harakiri.Mixfile do
  use Mix.Project

  def project do
    [app: :harakiri,
     version: "1.1.1",
     elixir: ">= 1.0.0",
     package: package(),
     description: """
        Help applications do things to themselves.
      """,
     deps: [{:ex_doc, ">= 0.0.0", only: :dev}]]
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
