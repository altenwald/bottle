# This is an example you can use for create your own checks
# to be in use with bottle. You need only to define data to be
# returned as the result of the evaluation of this file.
use Bottle, :checks

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
  message: fn pname, type ->
    %Conn{stanza_type: "message", type: ^type} = Client.get_conn(pname)
  end
]
