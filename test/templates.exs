import Exampple.Xml.Xmlel, only: [sigil_x: 2]
alias Exampple.Xml.Xmlel

[
  chat: fn options ->
    to_jid = Exampple.Xmpp.Jid.to_bare(options[:to])

    body =
      with {:body, nil} <- {:body, options[:body]},
           {:payload, nil} <- {:payload, options[:payload]} do
        ~x[<body/>]
      else
        {:body, body} ->
          Xmlel.new("body", %{}, [body])

        {:payload, payload} ->
          payload
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
  end
]
