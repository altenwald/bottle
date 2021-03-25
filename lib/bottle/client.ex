defmodule Bottle.Client do
  alias Bottle.CLI
  alias Exampple.Xml.Xmlel

  @default_host "localhost"
  @default_domain "example.com"
  @default_timeout 500
  @default_process_name to_string(Bottle.Client)
  @default_port 5222
  @default_tls false

  @spec recv(map(), timeout()) :: map()
  def recv(%{"process_name" => pname} = data, timeout \\ @default_timeout) do
    if (conn = Exampple.Client.get_conn(pname, timeout)) != :timeout do
      if data["store"] do
        Map.put(data, "conns", [conn | data["conns"] || []])
      else
        data
      end
      |> recv(timeout)
    else
      data
    end
  end

  @spec get_conn(map(), integer()) :: nil | Exampple.Router.Conn.t()
  def get_conn(data, idx \\ 0)
  def get_conn(%{"conns" => conns}, idx), do: Enum.at(conns, idx)
  def get_conn(%{}, _idx), do: nil

  defp values(data, keys) do
    for key <- keys do
      case key do
        {:key, real_key} -> data[real_key]
        {real_key, value} when is_atom(real_key) -> value
        _ when is_binary(key) -> data[key]
      end
    end
  end

  def send_template(%{"process_name" => pname} = data, name, keys \\ []) do
    Exampple.Client.send_template(name, values(data, keys), pname)
    data
  end

  def upgrade_tls(%{"process_name" => pname} = data) do
    Exampple.Client.upgrade_tls(pname)
    data
  end

  def check!(%{"process_name" => pname} = data, name, keys \\ []) do
    args = values(data, keys)
    result = Exampple.Client.check!(name, [pname | args], pname)
    Map.merge(data, result)
  rescue
    error -> raise "check!<#{inspect(pname)}> #{inspect(name)}#{inspect(keys)} ==> #{inspect(error)}"
  end

  def send_stanza(data, %Xmlel{} = stanza) do
    send_stanza(data, to_string(stanza))
  end

  def send_stanza(%{"process_name" => pname} = data, stanza) do
    Exampple.Client.send(stanza, pname)
    data
  end

  def disconnect(data) do
    Exampple.Client.stop(data["process_name"])
    data
  end

  def connect(data \\ %{}, name \\ @default_process_name) do
    data
    |> CLI.add_string("host", @default_host)
    |> CLI.add_string("domain", @default_domain)
    |> CLI.add_atom("process_name", name)
    |> client_start()
    |> register_templates()
    |> register_checks()
    |> client_connect()
    |> recv()
  end

  defp client_connect(%{"process_name" => pname} = data) do
    Exampple.Client.connect(pname)
    data
  end

  defp register_templates(%{"process_name" => pname} = data) do
    for {key, fun} <- Bottle.templates(data["domain"]) do
      Exampple.Client.add_template(pname, key, fun)
    end
    data
  end

  defp register_checks(%{"process_name" => pname} = data) do
    for {key, fun} <- Bottle.checks(data["domain"]) do
      Exampple.Client.add_check(pname, key, fun)
    end
    data
  end

  defp client_start(%{"process_name" => pname} = data) do
    Exampple.Client.start_link(pname, %{
      host: data["host"],
      domain: data["domain"],
      port: data["port"] || @default_port
    })
    data
  end

  def is_connected?(%{"process_name" => pname}) do
    Exampple.Client.is_connected?(pname)
  end

  def login(data) do
    data
    |> CLI.add_boolean("tls", @default_tls)
    |> CLI.add_string("stream_mgmt", "enable")
    |> case do
      %{"tls" => true} = data ->
        data
        |> send_template(:starttls)
        |> check!(:starttls)
        |> upgrade_tls()
        |> check!(:features)

      data -> data
    end
    |> send_template(:auth, ["user", "pass"])
    |> check!(:auth)
    |> send_template(:init, ["host"])
    |> check!(:init)
    |> case do
      %{"stream_mgmt" => "resume"} = data ->
        data
        |> CLI.add_string("stream_id")
        |> CLI.add_string("h", "1")
        |> send_template(:stream_mgmt_resume, ["stream_id", "h"])
        |> check!(:stream_mgmt_resumed)

      %{"stream_mgmt" => "enable"} = data ->
        data
        |> send_template(:bind, ["resource"])
        |> check!(:bind)
        |> send_template(:stream_mgmt_enable)
        |> check!(:stream_mgmt_enabled)

      data ->
        data
        |> send_template(:bind, ["resource"])
        |> check!(:bind)
    end
    |> case do
      %{"initial_presence" => false} = data ->
        data

      data ->
        data
        |> send_template(:presence)
        |> check!(:presence)
    end
  end
end
