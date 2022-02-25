use Bottle, :checks

require Logger

alias Exampple.Xmpp.Jid

[
  message: fn {:received, _pid, data}, opts ->
    type = opts[:type]
    %Conn{stanza_type: "message", type: ^type} = conn = data[:conn]
    [%Xmlel{children: [body]}] = conn.stanza["body"]
    %{"body" => body}
  end
]
