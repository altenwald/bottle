defmodule Bottle.Template do
  @moduledoc """
  Ensure the configuration of the templates is loaded in addition to
  the default templates.
  """
  alias Exampple.Xml.Xmlel

  @xmlns_stream_mgmt "urn:xmpp:sm:3"
  @xmlns_tls "urn:ietf:params:xml:ns:xmpp-tls"
  @xmlns_sasl "urn:ietf:params:xml:ns:xmpp-sasl"
  @xmlns_bind "urn:ietf:params:xml:ns:xmpp-bind"

  def setup(template_path_file) do
    Exampple.Template.init()
    for {key, fun} <- default_templates(), do: put(key, fun)

    for {key, fun} <- Bottle.get_templates(template_path_file) do
      put(key, fun)
    end
  end

  def put(key, fun) when not is_binary(key) do
    put(to_string(key), fun)
  end

  def put(key, fun), do: Exampple.Template.put(key, fun)

  def render!(name, bindings) when not is_binary(name) do
    render!(to_string(name), bindings)
  end

  def render!(name, bindings) do
    case Exampple.Template.render!(name, bindings) do
      %Xmlel{} = xmlel -> to_string(xmlel)
      binary when is_binary(binary) -> binary
    end
  end

  defp default_templates do
    [
      starttls: "<starttls xmlns='#{@xmlns_tls}'/>",
      auth: fn user: user, password: password ->
        base64 = Base.encode64(<<0, user::binary, 0, password::binary>>)
        Bottle.Logger.info("auth", "user=#{inspect(user)} password=#{inspect(password)} hash=#{inspect(base64)}")

        Xmlel.new("auth", %{"xmlns" => @xmlns_sasl, "mechanism" => "PLAIN"}, [base64])
      end,
      # init is a special XML chunk because it's opening the stream
      # but it's not closed until the connection is closed.
      init:
        "<?xml version='1.0' encoding='UTF-8'?>" <>
          "<stream:stream to='%{domain}' xmlns='jabber:client' " <>
          "xmlns:stream='http://etherx.jabber.org/streams' " <>
          "version='1.0'>",
      bind: fn resource: resource ->
        Xmlel.new(
          "iq",
          %{"type" => "set", "id" => "bind3", "xmlns" => "jabber:client"},
          [
            Xmlel.new("bind", %{"xmlns" => @xmlns_bind}, [
              Xmlel.new("resource", %{}, [resource])
            ])
          ]
        )
      end,
      stream_mgmt_enable: fn [] ->
        Xmlel.new("enable", %{"xmlns" => @xmlns_stream_mgmt, "resume" => "true", "max" => "60"})
      end,
      stream_mgmt_resume: fn h: h, stream_id: stream_id ->
        Xmlel.new("resume", %{"xmlns" => @xmlns_stream_mgmt, "h" => h, "previd" => stream_id})
      end,
      presence: "<presence/>"
    ]
  end
end
