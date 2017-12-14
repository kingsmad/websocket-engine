# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :example, ExampleWeb.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "hrufpKGP9jdGkwuetFaSHLc3qopzBoISBUhglIulV4PAfI0Iy0oZOhTx3oSMU5Vn",
  render_errors: [accepts: ~w(json)],
  pubsub: [name: ExampleWeb.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# config ecto
config :example, Example.Repo,
  adapter: Sqlite.Ecto2,
  database: "#{Mix.env}.sqlite3"

config :example, ecto_repos: [Example.Repo]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"