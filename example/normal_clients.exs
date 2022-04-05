use Bottle, :scenario

CLI.banner "Login user1"

user1 =
  config(System.get_env("USER1", "user1.exs"))
  |> connect()
  |> login()

CLI.banner "Login user2"

user2 =
  config(System.get_env("USER2", "user2.exs"))
  |> connect()
  |> login()

CLI.banner "Send message from user1 to user2"

user1
|> send_template(:message, [
  to_jid: get_bare_jid(user2),
  type: "chat",
  payload: "<body>Hello!</body>"
])
|> check!(:stream_mgmt_r)
|> send_template(:stream_mgmt_a, [h: "1"])

CLI.banner "User2 receives the message"

user2 = check!(user2, :message, ["chat"])

CLI.banner "User2 sends back a reply"

reply = Stanza.message_resp(user2["conn"], [~x[<body>OK!</body>]])

send_stanza(user2, reply)

check!(user1, :message)

CLI.banner "Teardown!"

disconnect(user1)
disconnect(user2)
