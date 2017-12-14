defmodule Example.TwitterClient do
  import Ecto.Query, only: [from: 2]
  @moduledoc false
  require Logger
  alias Phoenix.Channels.GenSocketClient
  @behaviour GenSocketClient

  def start_link(user_name) do
    GenSocketClient.start_link(
          __MODULE__,
          Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,
          ["ws://localhost:4000/socket/websocket", user_name]
        )
  end

  def init([url, user_name]) do
    Logger.info("initing #{inspect user_name}...")
    query = from u in "users",
              where: u.name == ^user_name,
              select: %{priv: u.private_key, pub: u.public_key} 
    res = Example.Repo.all(query)
    #Logger.info("HHH repo: #{inspect res}")
    {priv, pub} =
      case res do
        [] ->
          {:ok, {priv, pub}} = RsaEx.generate_keypair
          %Example.User{name: user_name, public_key: pub, private_key: priv}
            |> Example.Repo.insert!
          {priv, pub}
        [user] ->
          {user.private_key, user.public_key} 
      end

    {:connect, url, [{"user_id", user_name}, {"client_pub_key", pub}], 
      %{first_join: true, tw_ref: 1, 
        user_name: user_name, auth: false, 
        client_rsa_key: %{priv: priv, pub: pub},
        server_pub_key: nil}}
  end

  # public api
  def push_tweet(client, msg) do
    Process.send(client, {:push_tweet, msg}, [])
  end
  def push_tweet(client, msg, at_user, tag) do
    msg = msg <> " @" <> at_user <> " #" <> tag
    push_tweet(client, msg)
  end

  def watch_topics(client, %{users: users, tags: tags}) do
    topics = Enum.reduce(users, [], fn(t, acc) -> ["user_chan:"<>t | acc] end)
    topics = Enum.reduce(tags, topics, fn(t, acc) -> ["tag_chan:"<>t | acc] end)
    Process.send(client, {:watch, topics}, [])
  end

  def watch_users(client, users) do
    watch_topics(client, %{users: users, tags: []})
  end

  def watch_tags(client, tags) do
    watch_topics(client, %{users: [], tags: tags})
  end

  def unwatch_topics(client, %{users: users, tags: tags}) do
    topics = Enum.reduce(users, [], fn(t, acc) -> ["user_chan:"<>t | acc] end)
    topics = Enum.reduce(tags, topics, fn(t, acc) -> ["tag_chan:"<>t | acc] end)
    Process.send(client, {:unwatch, topics}, [])
  end

  def unwatch_users(client, users) do
    unwatch_topics(client, %{users: users, tags: []})
  end

  def unwatch_tags(client, tags) do
    unwatch_topics(client, %{users: [], tags: tags})
  end

  # handlers
  def handle_connected(transport, state) do
    Logger.info("client:#{inspect state.user_name} connected to server!")
    GenSocketClient.join(transport, "notification:"<>state.user_name)
    {:ok, state}
  end

  def handle_disconnected(reason, state) do
    Logger.error("client:#{inspect state.user_name} disconnected: #{inspect reason}")
    Process.send_after(self(), :connect, :timer.seconds(1))
    {:ok, state}
  end

  def handle_joined(topic, _payload, _transport, state) do
    Logger.info("client:#{inspect state.user_name} joined the topic #{topic}")

    # if state.first_join do
    watch_users(self(), [state.user_name])
    #end

    #:timer.send_interval(:timer.seconds(1), self(), :push_tweet)
    {:ok, %{state | first_join: false, tw_ref: 1}}
  end

  def handle_join_error(topic, payload, _transport, state) do
    Logger.error("client:#{inspect state.user_name} join error on the topic #{topic}: #{inspect payload}")
    {:ok, state}
  end

  def handle_channel_closed(topic, payload, _transport, state) do
    Logger.error("client:#{inspect state.user_name} disconnected from the topic #{topic}: #{inspect payload}")
    Process.send_after(self(), {:join, topic}, :timer.seconds(1))
    {:ok, state}
  end

  # handle challenge phase 
  def handle_message(_topic, _ref, 
                   %{"response" => %{"server_pub_key" => pub_key, "challenge" => str}}, 
                   transport, state) 
  do
    Logger.info("client:#{inspect state.user_name}-> received server challenge")
    #{:ok, pub_key} = RsaEx.decrypt(pub_key, state.client_rsa_key.priv)
    #Logger.info("client:#{state.user_name}-> received server public key from engine")
    #Logger.info("  decrypted  public key: #{pub_key}")

    {:ok, decrypted_str} = RsaEx.decrypt(str, state.client_rsa_key.priv)
    
    Logger.info("client:#{state.user_name}-> encrypted server challenge str: #{decrypted_str}")

    {:ok, enc_str} = RsaEx.encrypt(decrypted_str <> "######" <>
      Integer.to_string(:os.system_time(:millisecond)), pub_key)

    chan_str = "notification:" <> state.user_name
    GenSocketClient.push(transport, chan_str, "challenge_answer", %{"msg" => enc_str})

    {:ok, %{state | server_pub_key: pub_key, auth: true}}
  end

  def handle_message(topic, _event, payload, _transport, state) do
    Logger.warn("client:#{inspect state.user_name} received message on topic #{inspect topic} with content:\n#{inspect payload}")
    {:ok, state}
  end

  def handle_reply("ping", _ref, %{"status" => "ok"} = payload, _transport, state) do
    Logger.info("client:#{state.user_name} received reply from engine: #{payload}")
    {:ok, state}
  end
  def handle_reply(topic, _ref, payload, _transport, state) do
    Logger.warn("client:#{state.user_name}-> unexpected msg on topic #{topic}: #{inspect payload}")
    {:ok, state}
  end

  def handle_info({:push_tweet, msg}, transport, state) do
    chan_str = "notification:" <> state.user_name
    #Logger.info("on client, trying to push tweet: #{msg}")
    GenSocketClient.push(transport, chan_str, "twitter", 
                         %{"twitter" => msg})
    {:ok, state}
  end
  def handle_info({:watch, topics}, transport, state) do
    chan_str = "notification:" <> state.user_name
    Logger.info("client:#{state.user_name} is trying to watch #{inspect topics}")
    GenSocketClient.push(transport, chan_str, "watch", 
                         %{"topics" => topics})
    {:ok, state}
  end
  def handle_info({:unwatch, topics}, transport, state) do
    #Logger.info("on client, unwatch is called")
    chan_str = "notification:" <> state.user_name
    GenSocketClient.push(transport, chan_str, "unwatch", 
                         %{"topics" => topics})
    {:ok, state}
  end
  def handle_info(:connect, _transport, state) do
    Logger.info("client:#{state.user_name} re-connecting to engine...")
    {:connect, state}
  end
  def handle_info({:join, topic}, transport, state) do
    Logger.info("client:#{state.user_name} joining the topic #{topic} ...")
    case GenSocketClient.join(transport, topic) do
      {:error, reason} ->
        Logger.error("error joining the topic #{topic}: #{inspect reason}")
        Process.send_after(self(), {:join, topic}, :timer.seconds(1))
      {:ok, _ref} -> :ok
    end
    {:ok, state}
  end
  def handle_info(:ping_server, transport, state) do
    Logger.info("client:#{state.user_name} sending ping ##{state.tw_ref}")
    GenSocketClient.push(transport, "ping", "ping", %{tw_ref: state.tw_ref})
    {:ok, %{state | tw_ref: state.tw_ref + 1}}
  end
  def handle_info(message, _transport, state) do
    Logger.warn("client:#{state.user_name} unhandled message #{inspect message}")
    {:ok, state}
  end
end
