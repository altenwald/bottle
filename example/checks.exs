# This is an example you can use for create your own checks
# to be in use with bottle. You need only to define data to be
# returned as the result of the evaluation of this file.
use Bottle, :checks

require Logger

alias Exampple.Xmpp.Jid

[
  message: fn _pname, conn, type ->
    %Conn{stanza_type: "message", type: ^type} = conn
  end,
  chat: fn pname, conn, options ->
    from_jid =
      options[:from]
      |> Bottle.Bot.Server.get_jid()
      |> to_string()

    type = options[:type] || "chat"
    Logger.info("(#{pname}) checking #{inspect(from_jid)} #{inspect(type)} ==> #{inspect(conn.from_jid.original)} #{inspect(conn.stanza_type)} #{inspect(conn.type)}")
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
