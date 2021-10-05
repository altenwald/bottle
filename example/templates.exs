# This is an example you can use for create your own templates
# to be in use with bottle. You need only to define data to be
# returned as the result of the evaluation of this file.

import Exampple.Xml.Xmlel, only: [sigil_x: 2]
alias Exampple.Xml.Xmlel

[
  chat: fn options ->
    to_jid =
      options[:to]
      |> Bottle.Bot.Server.get_jid()
      |> Exampple.Xmpp.Jid.to_bare()

    body =
      case {options[:payload], options[:body]} do
        {nil, nil} -> ~x[<body/>]
        {nil, body} -> Xmlel.new("body", %{}, [body])
        {payload, _} -> payload
      end

    Xmlel.new("message", %{
      "id" => UUID.uuid4(),
      "to" => to_jid,
      "type" => "chat"
    }, [
      body,
      ~x[<markable xmlns='urn:xmpp:chat-markers:0'/>],
      ~x[<origin-id xmlns='urn:xmpp:sid:0' id='#{options[:origin_id]}'/>]
    ])
    |> to_string()
  end,
  message: fn to_jid, type, payload ->
    "<message id='#{UUID.uuid4()}' to='#{to_jid}' type='#{type}'>#{payload}</message>"
  end,
  received: fn options ->
    to_jid =
      options[:to]
      |> Bottle.Bot.Server.get_jid()
      |> Exampple.Xmpp.Jid.to_bare()

    "<message id='#{UUID.uuid4()}' to='#{to_jid}' type='chat'>" <>
      "<received xmlns='urn:xmpp:chat-markers:0' id='#{options[:origin_id]}'/>" <>
      "</message>"
  end,
  displayed: fn options ->
    to_jid =
      options[:to]
      |> Bottle.Bot.Server.get_jid()
      |> Exampple.Xmpp.Jid.to_bare()

    "<message id='#{UUID.uuid4()}' to='#{to_jid}' type='chat'>" <>
      "<displayed xmlns='urn:xmpp:chat-markers:0' id='#{options[:origin_id]}'/>" <>
      "</message>"
  end,
  stream_mgmt_enable: fn ->
    "<enable xmlns='urn:xmpp:sm:3' resume='true' max='60'/>"
  end,
  stream_mgmt_resume: fn previd, h ->
    "<resume xmlns='urn:xmpp:sm:3' previd='#{previd}' h='#{h}'/>"
  end,
  stream_mgmt_a: fn h ->
    "<a xmlns='urn:xmpp:sm:3' h='#{h}'/>"
  end,
  stream_mgmt_r: fn ->
    "<r xmlns='urn:xmpp:sm:3'/>"
  end
]
