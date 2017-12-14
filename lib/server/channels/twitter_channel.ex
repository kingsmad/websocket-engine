defmodule ExampleWeb.TwitterChannel do
  use Phoenix.Channel
  require Logger

  def join("notification:" <> _user, _params, socket) do
    chan = "user_chan:" <> socket.assigns[:user_id]
    Process.send_after(self(), :check_auth, 100)
    {:ok, socket 
      |> assign(:topics, [chan])
      |> put_new_topics([chan])}
  end

  def handle_in("challenge_answer", %{"msg" => msg}, socket) do
    Logger.info("engine: Challenge answer received, analysing...")
    {:ok, msg} = RsaEx.decrypt(msg, socket.assigns.server_priv_key) 
    Logger.info("engine: decrypted msg is #{inspect msg}")
    [recovered_msg | [pre_ts]] = String.split(msg, "######", trim: true)
    cur_ts = Integer.to_string(:os.system_time(:millisecond)) 

    if recovered_msg == socket.assigns.original_challenge_msg and cmp_timestamp(pre_ts, cur_ts) do
      Logger.info("engine: challenge of #{socket.assigns[:user_id]} completed!")
      {:noreply, socket |> assign(:challenge_phase, 4)}
    else
      Logger.info("engine: challenge of #{socket.assigns[:user_id]} failed!")
      Logger.info("engine: got recovered_msg: #{recovered_msg} and original_challenge_msg #{inspect socket.assigns.original_challenge_msg}\n previous timestamp: #{inspect pre_ts}, current timestamp: #{inspect cur_ts}")
      {:noreply, socket}
    end
  end
  def handle_in("watch", %{"topics" => topics}, socket) do
    {res, socket} = check_auth(socket)
    if res do
      Logger.info("engine: #{inspect socket.assigns[:user_id]} is watching #{inspect topics}")
      {:reply, :ok, put_new_topics(socket, topics)}
    else
      {:noreply, socket}
    end
  end
  def handle_in("unwatch", %{"topics" => topics}, socket) do
    {res, socket} = check_auth(socket)
    if res do
      Logger.info("engine: #{inspect socket.assigns[:user_id]} is unwatching #{inspect topics}")
      Enum.map(topics, fn x -> ExampleWeb.Endpoint.unsubscribe(x) end)
      {:reply, :ok, socket}
    else
      {:noreply, socket}
    end
  end
  def handle_in("twitter", %{"twitter" => msg}, socket) do
    Process.send_after(self(), :russian_roulette, 1000)
    {res, socket} = check_auth(socket)
    if res do
      source_user = socket.assigns[:user_id]
      Logger.info("engine: received twitter from #{source_user}")
      channel_list = parse_tweet(msg, source_user)
      Logger.info("dispatching to channels #{inspect channel_list}")
      
      Enum.map(channel_list, fn chan -> 
        ExampleWeb.Endpoint.broadcast chan, "down_msg", %{"twitter" => msg, "source_user" => source_user}
        end)
    end
    {:noreply, socket}
  end
  def handle_in(ev, msg, socket) do
    {res, socket} = check_auth(socket)
    if res do
      Logger.info("engine: unexpected msg: #{inspect ev} <> #{inspect msg}")
    else
    end
    {:noreply, socket}
  end

  defp parse_tweet(str, user) do
    channel_list = ["user_chan:" <> user]
    channel_list = 
      if String.match?(str, ~r/@/) do
        user = str |> String.split("@", parts: 2) |> List.last |> String.split 
               |> List.first |> String.trim_trailing(".") 
               |> String.trim_trailing(",")
        ["user_chan:" <> user | channel_list] 
      else
        channel_list
      end
    channel_list = 
      if String.match?(str, ~r/#/) do
        tag = str |> String.split("#", parts: 2) |> List.last |> String.split 
              |> List.first |> String.trim_trailing(",") 
              |> String.trim_trailing(".")
        ["tag_chan:" <> tag | channel_list]
      else
        channel_list
      end
    Enum.uniq(channel_list)
  end

  defp put_new_topics(socket, topics) do
    Enum.reduce(topics, socket, fn topic, acc ->
      topics = acc.assigns.topics
      if topic in topics do
        acc
      else
        :ok = ExampleWeb.Endpoint.subscribe(topic)
        assign(acc, :topics, [topic | topics])
      end
    end)
  end

  def check_auth(socket) do
    case socket.assigns.challenge_phase do
      0 ->
        Logger.info("engine: challenge_phase is 0, sending pub_key and challenge msg to client #{socket.assigns.user_id}")
        msg = "A secret makes woman woman" <> Integer.to_string(:os.system_time(:millisecond))
        socket = socket |> assign(:original_challenge_msg, msg)

        # generate temporary rsa keys
        {:ok, msg} = RsaEx.encrypt(msg, socket.assigns.client_pub_key)
        {:ok, {priv, pub}} = RsaEx.generate_keypair
        socket = socket |> assign(:server_pub_key, pub) |> assign(:server_priv_key, priv)

        # start challenge 
        push socket, "challenge", 
          %{"response" => %{"server_pub_key" => pub, "challenge" => msg}}

        socket = socket |> assign(:challenge_phase, 1)
        Process.send_after(self(), :challenge_time_out, :timer.seconds(1))
        {false, socket}
      4 ->
        Logger.info("engine: challenge_phas is 4, auth is done for #{socket.assigns.user_id}")
        {true, socket}
      1 ->
        Logger.info("engine: still waiting for challenge answer...")
        {false, socket}
      _ ->
        Logger.info("engine: unexpected challenge phase")
        {false, socket}
    end
  end

  def handle_info(:challenge_time_out, socket) do
    if socket.assigns.challenge_phase == 1 do
      Logger.info("engine: challenge of #{inspect socket.assigns[:user_id]} timeout!")
      {:noreply, socket |> assign(:challenge_phase, 0)} 
    else
      {:noreply, socket}
    end
  end

  alias Phoenix.Socket.Broadcast
  def handle_info(%Broadcast{topic: _, event: ev, payload: payload}, socket) do
      push socket, ev, payload
      {:noreply, socket}
  end

  def handle_info(:russian_roulette, socket) do
    Logger.info("engine: #{inspect socket.assigns[:user_id]} entering russian roulette")
    if :rand.uniform(10) == 1 do
      Logger.warn("engine: disconnecting #{socket.assigns[:user_id]}")
      Process.exit(socket.transport_pid, :kill)
      {:noreply, socket}
    else
      Logger.warn("engine: #{socket.assigns[:user_id]} suvived in russian roulette") 
      {:noreply, socket}
      #{:stop, :normal, socket}
    end
  end

  def handle_info(:check_auth, socket) do
    {_, socket} = check_auth(socket)
    {:noreply, socket}
  end

  def cmp_timestamp(ts1, ts2) do
    if Kernel.abs(String.to_integer(ts1) - String.to_integer(ts2)) < 1000 do
      true
    else
      false
    end
  end

end
