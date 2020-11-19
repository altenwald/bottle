# This is an example you can use for create your own checks
# to be in use with bottle. You need only to define data to be
# returned as the result of the evaluation of this file.

alias Exampple.Client
alias Exampple.Router.Conn
alias Exampple.Xml.Xmlel

[
  auth: fn pname ->
    %Conn{stanza_type: "success"} = Client.get_conn(pname)
  end,
  starttls: fn pname ->
    %Conn{stanza_type: "proceed"} = Client.get_conn(pname)
  end,
  features: fn pname ->
    %Conn{stanza_type: "stream:features", stanza: stanza} = Client.get_conn(pname)
    [%Xmlel{name: "mechanisms"} = mech] = stanza["mechanisms"]
    true = %Xmlel{name: "mechanism", children: ["PLAIN"]} in mech["mechanism"]
    [%Xmlel{name: "register"}] = stanza["register"]
  end,
  groupchat: fn pname ->
    %Conn{stanza_type: "message", type: "groupchat"} = Client.get_conn(pname)
  end
]
