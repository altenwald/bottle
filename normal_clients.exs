alias Bottle.Client

%{
  "domain" => "example.com",
  "host" => "localhost",
  "pass" => "6feb633d-3be7-42d7-9a28-8c6c433fdc32",
  "resource" => "hectic",
  "user" => "7b9b68a9-dd87-44f9-94b1-869118156c73",
  "process_name" => :user1,

  "to_jid" => "e7264939-6604-4c73-a0ee-26d831ad9ef5@example.com",
  "type" => "chat",
  "payload" => "<body>Hello!</body>"
}
|> Client.connect()
|> Client.send_template(:auth, ["user", "pass"])
|> Client.send_template(:init, ["host"])
|> Client.send_template(:bind, ["resource"])
|> Client.send_template(:presence)
|> Client.send_template(:message, ["to_jid", "type", "payload"])
|> Client.disconnect()
