This is an demo-twitter server-engine && client built by websocket, phoenix via 
elixir.

Extra open source modules:
websocket client for elixir: https://github.com/Aircloak/phoenix_gen_socket_client
Rsa library: https://github.com/anoskov/rsa-ex

How to Run:
Enter following commands in EVERY RUN:

rm dev.sqlite3
mix ecto.create
mix ecto.migrate
iex -S mix phx.server | tee ./example.log

Design:
engine part: it is based on phoenix that provides websocket apis for 'subscribe',
'unsubscribe', 'push twitter' based on '@' and '#'. The engine will push contents
continously without active query from client-side. The engine will parse tweets
and push them to corresponding channels which stands for subscribers. (check log for
engine part)

clients: clients will register automatically at first, and in the simulator, they
will randomly send twitters from corpus to engine, and has probability (set in simulator)
to randomly @ some other user and push tags on the twitters. 

simulator: every second, the simulator will operates the clients to send random 
tweets.

Log: all the status and results are stored in the log file. I uploaded an example
log


Authentication:
While the client is working, there is 10% prob that the engine will disconnect 
a random client. the client will automatically re-connect to the engine. Once 
re-connected, The engine will check for this client's -- say jolly1's --- 
original public-key, if there is no such key, that means we are in the registration
phase, engine will record the public-key uploaded by jolly1 and save for later use.
If previous public key is found, the engine will set 'challenge_phase' to un-auth
and start the challenge phase.
challenge phase:
1. engine send a temporary server-priv/pub rsa-2048 key, use client-pub key to
encrypt it and send this to jolly1. Also the challenge string is set by a random
string (acturally a fixed string tailed by current time), this string is encrypted
by clients public key.
2. When client recieved this challenge, jolly1 will use s/his private key to unlock
the msg and add current time to this challeng string, and then encrypt it by the
server-side-public-key provided by the engine, send it back.
3. When engine received this challenge answer, it will decrypte this string and 
check the tailling timestamp added by jolly1. If this timestamp is less than 1 
second comparing to the current time, engine will auth this jolly1.

Potential issue:
It seems there is always an issue with the function 

{:ok, {priv, pub}} = RsaEx.key_generate

provided by library when constantly called multiple times in step 1. 
see details in the end of example.log



