defmodule Bottle.ClientTest do
  use Exampple.Router.ConnCase, :client

  import Exampple.Xml.Xmlel, only: [sigil_x: 2]

  alias Bottle.Client
  alias Exampple.Router.Conn

  describe "config" do
    test "process user config file" do
      assert %{
        "process_name" => :user1,
        "tls" => false
      } = Client.config(Path.join(__DIR__, "user1.exs"))
    end

    test "config file not found" do
      assert_raise Code.LoadError, fn -> Client.config("notfound.exs") end
    end
  end

  describe "send_template" do
    setup do
      Exampple.DummyTcpClient.dump()
      Bottle.Template.setup(Path.join(__DIR__, "templates.exs"))

      data =
        Client.config(Path.join(__DIR__, "user1.exs"))
        |> Map.put("tcp_handler", Exampple.DummyTcpClient)
        |> Client.connect()

      Exampple.Client.wait_for_connected()
      Exampple.DummyTcpClient.subscribe()

      %{data: data}
    end

    test "sending a default template", %{data: data} do
      assert data == Client.send_template(data, :presence)
      assert_stanza_receive ~x[<presence/>]
    end

    test "sending a default template with params", %{data: data} do
      assert data == Client.send_template(data, :auth, ~w[ user password ])
      assert_stanza_receive ~x[
        <auth mechanism="PLAIN" xmlns="urn:ietf:params:xml:ns:xmpp-sasl">
          ADdiOWI2OGE5LWRkODctNDRmOS05NGIxLTg2OTExODE1NmM3MwA3YjliNjhhOS1kZDg3LTQ0ZjktOTRiMS04NjkxMTgxNTZjNzM=
        </auth>
      ]
    end

    test "sending a configured template with params", %{data: data} do
      origin_id = UUID.uuid4(:hex)
      message_id = UUID.uuid4(:hex)
      options = [
        to: "User1@example.com",
        body: "Hello world!",
        origin_id: origin_id,
        message_id: message_id
      ]
      assert data == Client.send_template(data, :chat, options)
      assert_stanza_receive ~x[
        <message to="user1@example.com" type="chat" id="#{message_id}">
          <body>Hello world!</body>
          <markable xmlns="urn:xmpp:chat-markers:0"/>
          <origin-id xmlns="urn:xmpp:sid:0" id="#{origin_id}"/>
        </message>
      ]
    end

    test "sending a missing template", %{data: data} do
      assert_raise ArgumentError, "not_found", fn -> Client.send_template(data, :missing) end
    end
  end

  describe "check!" do
    setup do
      Exampple.DummyTcpClient.dump()
      Bottle.Checks.setup(Path.join(__DIR__, "checks.exs"))

      data =
        Client.config(Path.join(__DIR__, "user1.exs"))
        |> Map.put("tcp_handler", Exampple.DummyTcpClient)
        |> Client.connect()

      Exampple.Client.wait_for_connected()
      Exampple.DummyTcpClient.subscribe()

      %{data: data}
    end

    test "using a default check", %{data: data} do
      client_received ~x[<presence/>]
      assert %{ "conn" => %Conn{} } = Client.check!(data, :presence, timeout: 500)
    end

    test "using a default check with return", %{data: data} do
      client_received ~x[<enabled resume='true' xmlns='urn:xmpp:sm:3' id='enable1'/>]
      assert %{
        "conn" => %Conn{},
        "stream_id" => "enable1",
        "stream_timeout" => nil,
      } = Client.check!(data, :stream_mgmt_enabled, timeout: 500)
    end

    test "using a configured check with options", %{data: data} do
      client_received ~x[<message type='chat'><body>Hello world!</body></message>]
      assert Map.put(data, "body", "Hello world!") == Client.check!(data, :message, timeout: 500, type: "chat")
    end

    test "using a missing check", %{data: data} do
      assert_raise RuntimeError, ~r/:error, :check_not_found/, fn -> Client.check!(data, :missing) end
    end
  end
end
