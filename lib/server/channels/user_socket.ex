defmodule ExampleWeb.UserSocket do
  import Ecto.Query, only: [from: 2]
  use Phoenix.Socket

  require Logger

  ## Channels
  channel "ping", ExampleWeb.PingChannel

  channel "notification:*", ExampleWeb.TwitterChannel

  ## Transports
  transport :websocket, Phoenix.Transports.WebSocket
  # transport :longpoll, Phoenix.Transports.LongPoll

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(params, socket) do
    Logger.info("Received new connection with params: #{inspect params}")
    claimed_name = params["user_id"]
    query_name = claimed_name <> "kingsmad_engine_server"
    query = from u in "users",
              where: u.name == ^query_name,
              select: u.public_key

    #{:ok, {priv, pub}} = RsaEx.generate_keypair
    #socket = socket |> assign(:server_pub_key, pub) |> assign(:server_priv_key, priv)

    case Example.Repo.all(query) do
      [] ->
        Logger.info("No registered user named #{claimed_name} found, ask for registration!")
        if Map.has_key?(params, "client_pub_key") do
          #Logger.info("engine: in connecting phase, received client_pub_key: #{inspect client_pub_key}")
          %Example.User{name: claimed_name<>"kingsmad_engine_server", public_key: params["client_pub_key"]} |> Example.Repo.insert!
          {:ok, socket |> assign(:user_id, claimed_name) |> assign(:challenge_phase, 4)}
        else
          :error
        end
      [pub_key] ->
        Logger.info("previous pub_key found for #{inspect claimed_name}, starting auth challenge.")
        Logger.info("previous pub_key is: #{inspect pub_key}")
        {:ok, 
          socket 
          |> assign(:user_id, claimed_name) 
          |> assign(:client_pub_key, pub_key)
          |> assign(:challenge_phase, 0)
        }
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "users_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Example.Endpoint.broadcast("users_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  #def id(socket), do: "users_socket:#{socket.assigns.user_id}"
  def id(_socket), do: nil
end
