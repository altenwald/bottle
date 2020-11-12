# This is an example you can use for create your own checks
# to be in use with bottle. You need only to define data to be
# returned as the result of the evaluation of this file.

alias Exampple.Client
alias Exampple.Router.Conn

[
  auth: fn pname ->
    %Conn{stanza_type: "success"} = Client.get_conn(pname)
  end
]
