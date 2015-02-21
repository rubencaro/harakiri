defmodule Harakiri.Mixfile do
  use Mix.Project

  def project do
    [app: :harakiri,
     version: "0.2.0",
     elixir: "~> 1.0.0",
     package: package,
     description: """
        Help applications do things to themselves (ex. kill themselves).
        Given a list of _files_, an _application_, and an _action_. When any of the
        files change on disk (i.e. a gentle `touch` is enough), then the given action
        is fired over the app. `Harakiri` was concieved to help applications kill
        themselves in response to a `touch` to a file on disk. Hence the name.
      """]
  end

  def application do
    [mod: {Harakiri, []}]
  end

  defp package do
    [contributors: ["Rubén Caro"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/elpulgardelpanda/harakiri"}]
  end
end
