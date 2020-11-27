use Bottle, :scenario

CLI.banner "Login user1"

user1 =
  %{
    "user" => "7b9b68a9-dd87-44f9-94b1-869118156c73",
    "pass" => "7b9b68a9-dd87-44f9-94b1-869118156c73",
    "domain" => "example.com",
    "host" => "localhost",

    "tls" => false,
    "stream_mgmt" => "enable",
    "resource" => "hectic",
    "process_name" => :user1,
    "store" => true
  }
  |> connect()
  |> login()

CLI.banner "Login user2"

user2 =
  %{
    "user" => "e7264939-6604-4c73-a0ee-26d831ad9ef5",
    "pass" => "e7264939-6604-4c73-a0ee-26d831ad9ef5",
    "domain" => "example.com",
    "host" => "localhost",

    "tls" => false,
    "stream_mgmt" => "enable",
    "resource" => "hectic",
    "process_name" => :user2,
    "store" => true
  }
  |> connect()
  |> login()

CLI.banner "Send message from user1 to user2"

user1
|> send_template(:message, [
  to_jid: user2["user"] <> "@" <> user2["domain"],
  type: "chat",
  payload: "<body>Hello!</body>"
])
|> check!(:stream_mgmt_r)
|> send_template(:stream_mgmt_a, [h: "1"])

CLI.banner "User2 receives the message"

user2 =
  user2
  |> check!(:message, ["chat"])

CLI.banner "User2 sends back a reply"

reply = Stanza.message_resp(user2["conn"], [~x[<body>OK!</body>]])

user2
|> send_stanza(reply)

user1
|> check!(:message)

CLI.banner "Teardown!"

user1
|> disconnect()

user2
|> disconnect()
