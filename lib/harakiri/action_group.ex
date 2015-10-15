
defmodule Harakiri.ActionGroup do
  defstruct paths: [],
            app: nil,
            action: nil,
            lib_path: nil,
            metadata: [loops: 0, hits: 0]
end
