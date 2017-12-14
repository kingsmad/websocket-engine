defmodule Example.Mixfile do
  use Mix.Project

  def project do
    [app: :example,
     version: "0.0.1",
     elixir: "~> 1.5",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      extra_applications: [:logger, :sqlite_ecto2, :rsa_ex],
      mod: {Example, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.3.0"},
      {:gettext, "~> 0.9"},
      {:cowboy, "~> 1.0"},
      # Note: we're using a local dependency here to keep this project in sync with the repo state.
      # In regular production you should use the latest published hex version.
      #{:phoenix_gen_socket_client, path: "../"},
      {:phoenix_gen_socket_client, "~> 2.0.0"},
      {:poison, "~> 2.0"},
      {:websocket_client, "~> 1.2"},
      {:ecto, "~> 2.2.2"},
      {:sqlite_ecto2, "~> 2.2.1"},
      {:rsa_ex, "~> 0.1"}
    ]
  end
end
