use Mix.Config

config :logger, :console,
  level: :debug,
  format: "$time $metadata[$level] $message\n"

# improve testability
loop_sleep_ms = case Mix.env do
                  :test -> 1
                  _ -> 5_000
                end
config :harakiri, :loop_sleep_ms, loop_sleep_ms