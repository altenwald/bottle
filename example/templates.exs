# This is an example you can use for create your own templates
# to be in use with bottle. You need only to define data to be
# returned as the result of the evaluation of this file.

import Exampple.Xml.Xmlel, only: [sigil_x: 2]
alias Exampple.Xml.Xmlel

[
  chat: fn options ->
    to_jid = Exampple.Xmpp.Jid.to_bare(options[:to])

    body =
      case {options[:payload], options[:body]} do
        {nil, nil} -> ~x[<body/>]
        {nil, body} -> Xmlel.new("body", %{}, [body])
        {payload, _} -> payload
      end

    Xmlel.new("message", %{
      "id" => options[:message_id] || UUID.uuid4(),
      "to" => to_jid,
      "type" => "chat"
    }, [
      body,
      ~x[<markable xmlns='urn:xmpp:chat-markers:0'/>],
      ~x[<origin-id xmlns='urn:xmpp:sid:0' id='#{options[:origin_id]}'/>]
    ])
  end,
  message: fn options ->
    to_jid = Exampple.Xmpp.Jid.to_bare(options[:to])
    message_id = options[:message_id] || UUID.uuid4()
    payload = options[:payload]
    type = options[:type] || "chat"

    Xmlel.new(
      "message",
      %{ "id" => message_id, "to" => to_jid, "type" => type},
      children: [payload])
  end,
  received: fn options ->
    to_jid = Exampple.Xmpp.Jid.to_bare(options[:to])
    message_id = options[:message_id] || UUID.uuid4()
    origin_id = options[:origin_id]

    Xmlel.new(
      "message",
      %{"id" => message_id, "to" => to_jid, "type" => "chat"},
      [
        Xmlel.new("received", %{
          "xmlns" => "urn:xmpp:chat-markers:0",
          "id" => origin_id
        })
      ])
  end,
  displayed: fn options ->
    to_jid = Exampple.Xmpp.Jid.to_bare(options[:to])
    message_id = options[:message_id] || UUID.uuid4()
    origin_id = options[:origin_id]

    ~x[
      <message id='#{message_id}' to='#{to_jid}' type='chat'>
        <displayed xmlns='urn:xmpp:chat-markers:0' id='#{origin_id}'/>
      </message>
    ]
  end,
  stream_mgmt_enable: "<enable xmlns='urn:xmpp:sm:3' resume='true' max='60'/>",
  stream_mgmt_resume: "<resume xmlns='urn:xmpp:sm:3' previd='%{previd}' h='%{h}'/>",
  stream_mgmt_a: "<a xmlns='urn:xmpp:sm:3' h='%{h}'/>",
  stream_mgmt_r: "<r xmlns='urn:xmpp:sm:3'/>"
]
