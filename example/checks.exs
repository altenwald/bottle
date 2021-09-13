# This is an example you can use for create your own checks
# to be in use with bottle. You need only to define data to be
# returned as the result of the evaluation of this file.
use Bottle, :checks

require Logger

alias Exampple.Xmpp.Jid

[
  features: fn pname ->
    %Conn{stanza_type: "stream:features", stanza: stanza} = conn = Client.get_conn(pname)
    [%Xmlel{name: "mechanisms"} = mech] = stanza["mechanisms"]
    true = %Xmlel{name: "mechanism", children: ["PLAIN"]} in mech["mechanism"]
    [%Xmlel{name: "register"}] = stanza["register"]
    conn
  end,
  stream_mgmt_enabled: fn pname ->
    %Conn{stanza_type: "enabled", stanza: %Xmlel{attrs: attrs}} = conn = Client.get_conn(pname)
    if attrs["resume"] == "true" do
      %{
        "conn" => conn,
        "stream_id" => attrs["id"],
        "stream_timeout" => attrs["max"]
      }
    else
      conn
    end
  end,
  stream_mgmt_resumed: fn pname ->
    %Conn{stanza_type: "resumed", stanza: %Xmlel{attrs: %{"h" => h}}} = conn = Client.get_conn(pname)
    %{"conn" => conn, "h" => h}
  end,
  stream_mgmt_r: fn pname ->
    %Conn{stanza_type: "r"} = Client.get_conn(pname)
  end,
  stream_mgmt_a: fn pname ->
    %Conn{stanza_type: "a", stanza: %Xmlel{attrs: %{"h" => h}}} = conn = Client.get_conn(pname)
    %{"conn" => conn, "h" => h}
  end,
  message: fn pname, conn, type ->
    %Conn{stanza_type: "message", type: ^type} = conn
  end,
  chat: fn pname, conn, options ->
    from_jid =
      options[:from]
      |> Bottle.Bot.Server.get_jid()
      |> to_string()

    type = options[:type] || "chat"
    Logger.info("checking (#{pname}) #{inspect(from_jid)} #{inspect(type)} ==> #{inspect(conn.from_jid.original)} #{inspect(conn.stanza_type)} #{inspect(conn.type)}")
    %Conn{from_jid: %Jid{original: ^from_jid}, stanza_type: "message", type: ^type} = conn
  end,
  received: fn _pname, conn, options ->
    from_jid =
      options[:from]
      |> Bottle.Bot.Server.get_jid()
      |> to_string()

    type = options[:type] || "chat"
    %Conn{from_jid: %Jid{original: ^from_jid}, stanza_type: "message", type: ^type} = conn
  end,
  displayed: fn _pname, conn, options ->
    from_jid =
      options[:from]
      |> Bottle.Bot.Server.get_jid()
      |> to_string()

    type = options[:type] || "chat"
    %Conn{from_jid: %Jid{original: ^from_jid}, stanza_type: "message", type: ^type} = conn
  end,
  receipt: fn _pname, conn, options ->
    from_jid =
      options[:from]
      |> Bottle.Bot.Server.get_jid()
      |> Jid.to_bare()

    type = options[:type] || "chat"
    %Conn{from_jid: %Jid{original: ^from_jid}, stanza_type: "message", type: ^type} = conn
  end
]
