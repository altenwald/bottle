defmodule Bottle.Client do
  @moduledoc """
  All of the functionality needed to configure and connect a XMPP
  client. It has also some dynamics needed for retrieving the
  configuration, use templates and perform checks.

  Most of the functions in this module uses a dataset. The dataset
  is a map which is containing a lot of needed information, like
  the process name (`process_name`) and those functions returns
  the same dataset modified. This way we can create pipe processing
  like this:

  ```elixir
  data
  |> connect()
  |> upgrade_tls()
  |> send_template(:message_hello, to: "jonny@xmpp.org")
  |> check!(:receipt)
  |> disconnect()
  ```
  """
  alias Bottle.CLI
  alias Bottle.{Checks, Template}
  alias Exampple.Xml.Xmlel

  @default_host "localhost"
  @default_domain "example.com"
  @default_process_name to_string(Bottle.Client)
  @default_port 5222
  @default_tls false
  @default_max_events 50
  @default_tcp_handler Exampple.Tcp

  @default_timeout 5_000

  defp values(data, keys) do
    for key <- keys do
      case key do
        {:key, real_key} when is_atom(real_key) ->
          {real_key, data[to_string(real_key)]}

        {real_key, value} when is_atom(real_key) ->
          {real_key, value}

        key when is_atom(key) ->
          {key, data[to_string(key)]}

        key when is_binary(key) ->
          {String.to_atom(key), data[key]}
      end
    end
  end

  @doc """
  Using the `Exampple.Template` functionality it's retrieving a rendered
  template and sending it to the server via client XMPP connection.

  The first parameter `data` must be a map with the `"process_name"` key
  defined. This could be a PID or a registered name pointing to an existent
  `Exampple.Client` process.

  The second parameter `name` is the key for retrieving the template, and
  the third parameter `keys` is a way to provide the data for the bindings
  of the template.

  Note that it requires to include all of the templates we want to use
  inside of the `templates.exs` file. See `Bottle.get_templates/1` for further
  information.
  """
  def send_template(%{"process_name" => pname} = data, name, keys \\ []) do
    Template.render!(name, values(data, keys))
    |> Exampple.Client.send(pname)

    data
  end

  @doc """
  Upgrades the connection to TLS requesting to the server starts the
  communication using a secure channel of communication.
  """
  def upgrade_tls(%{"process_name" => pname} = data) do
    Exampple.Client.upgrade_tls(pname)
    data
  end

  @doc """
  Performs a check. The check process (see `Bottle.Checks`) is
  tracing the client process (see `Exampple.Client`) and receiving all
  of the events. We can define checks for the received events (or events
  which will be receive until the timeout is triggered) and performs
  matching in some way.

  Note that the `checks.exs` file should contain the needed functions
  defined in a key-value pair and valid way. See `Bottle.get_checks/1` for
  further information.
  """
  def check!(%{"process_name" => pname} = data, name, keys \\ []) do
    opts =
      data
      |> values([:process_name | keys])
      |> Keyword.put(:timeout, data["timeout"] || @default_timeout)

    checks_pname = data["checks_process_name"] || checks_pname(pname)
    try do
      {:ok, {result, _event}} = Checks.validate(checks_pname, name, opts)
      case result do
        %struct_name{} ->
          key =
            struct_name
            |> to_string()
            |> String.downcase()
            |> String.split(".")
            |> List.last()

          Map.put(data, key, result)

        %{} ->
          Map.merge(data, result)

        _ ->
          Map.put(data, "result", result)
      end
    rescue
      error ->

        events =
          Checks.get_events(checks_pname)
          |> Enum.map(&"  #{inspect(&1)}")
          |> Enum.join("\n")

        raise """
        check!<#{inspect(pname)}> #{inspect(name)}#{inspect(keys)} ==> #{inspect(error)}

        data:
        #{inspect(data)}

        events:
        #{events}
        """
    end
  end

  @doc """
  Send a stanza. Indeed it supports to send a stanza in `Xmlel` type or
  even as a binary.

  The first parameter is the data set where must be present the key
  `"process_name"` containing a PID or a registered name for a process.
  """
  def send_stanza(data, %Xmlel{} = stanza) do
    send_stanza(data, to_string(stanza))
  end

  def send_stanza(%{"process_name" => pname} = data, stanza) do
    Exampple.Client.send(stanza, pname)
    data
  end

  @doc """
  Performs the disconnection. It's not stopping the client process.
  """
  def disconnect(data) do
    Exampple.Client.stop(data["process_name"])
    data
  end

  @doc """
  Performs the connection to the server providing optionally the
  data for the parameters. The first parameter is the dataset and
  the second parameter is the name of the process which will be
  created.

  Indeed, the second parameter isn't needed if that data is provided
  inside of the dataset. If no data is provided, the system will
  ask to the user via consola. The data required inside of the
  dataset is:

  - `host` the host where we should to be connected to the server.
    The default value is `localhost`.
  - `domain` the XMPP domain. The default value is `example.com`.
  - `process_name` which could be provided by the second parameter
    or be available inside of the dataset. The priority is: dataset,
    parameter or asking via console. The console suggest as default
    value the name `Bottle.Client`.

  This function is also performing other actions like:

  - Registering the templates from `templates.exs`.
  - Registering the checks from `checks.exs`.
  """
  def connect(data \\ %{}, name \\ @default_process_name) do
    data
    |> CLI.add_string("host", @default_host)
    |> CLI.add_string("domain", @default_domain)
    |> CLI.add_atom("process_name", name)
    |> client_start()
    |> client_connect()
  end

  defp client_connect(%{"process_name" => pname} = data) do
    Exampple.Client.connect(pname)
    data
  end

  defp checks_pname(pname), do: String.to_atom("#{pname}_checks")

  defp client_start(%{"process_name" => pname} = data) do
    {:ok, _pid} =
      Exampple.Client.start_link(pname, %{
        host: data["host"],
        domain: data["domain"],
        port: data["port"] || @default_port,
        tcp_handler: data["tcp_handler"] || @default_tcp_handler
      })

    checks_pname = checks_pname(pname)
    max_events = data["max_events"] || @default_max_events
    Bottle.Checks.start_link(checks_pname, pname, max_events)

    Bottle.Logger.add_client(pname)
    Bottle.Stats.add_client(pname)

    Map.put(data, "checks_process_name", checks_pname)
  end

  @doc """
  Asks to the client if it's connected to the server. It's using
  the dataset as the needed parameter and returning true or false.
  """
  def is_connected?(%{"process_name" => pname}) do
    Exampple.Client.is_connected?(pname)
  end

  @doc """
  Performs the login sequence. This is a bit complex function because
  it let us configure TLS, Stream Management, user, password, host,
  resource and if we should send the initial presence or not. The
  configuration parameters you can use inside of the dataset:

  - `tls` (boolean) if we are going to upgrade to TLS previously to
    perform the login.
  - `stream_mgmt` ("enable"|"resume"|"disable") it's saying if we are
    going to use stream management (XEP-0198) and if we set it as
    `"resume"` that we are going to use a previous session. For resume
    previous session we will need to have inside of the dataset:
    - `stream_id` (string) which is a previous Stream ID to be resumed.
    - `h` (string) the number of the message we requested last time.
  - `user` (string) the JID we have to use to login.
  - `password` (string) the password.
  - `domain` (string) the XMPP domain where we are connected.
  - `resource` (string) the name of the resource we want to use.
  - `initial_presence` (booelan) if we want to send the initial presence.

  In the same way, the use of the templates needed to support the login
  are loaded just in the creation of the client process, but they could
  be overloaded previously starting the login process. These are the
  templates:

  - `:starttls` (no params): stanza to send the request for starting the TLS.
  - `:auth` (user, password): stanza for the authentication.
  - `:init` (domain): starting the XMPP negotiation.
  - `:bind` (resource): create the bind for the resource.
  - `:stream_mgmt_resume` (stream_id, h): resume a stream management session.
  - `:stream_mgmt_enable` (no params): creates new session for stream
    management.
  - `:presence` (no params): the initial presence.

  See `Bottle.Template` for further information.

  We also need some checks, these are:

  - `:starttls`: performs a check to ensure the server is replying
    correctly to our request for start TLS.
  - `:features`: checking the features are how we expect.
  - `:auth`: ensure the auth is performed correctly.
  - `:init`: ensure the init is processed correctly.
  - `:stream_mgmt_resumed`: ensure the stream management is resumed.
  - `:stream_mgmt_enabled`: ensure the stream management is enabled.
  - `:bind`: checking the resource is bound correctly.
  - `:presence`: checking we receive the echo of our initial presence.

  See `Bottle.Checks.Storage`.
  """
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
    |> send_template(:auth, ~w[ user password ]a)
    |> check!(:auth)
    |> send_template(:init, ~w[ domain ]a)
    |> check!(:init)
    |> case do
      %{"stream_mgmt" => "resume"} = data ->
        data
        |> CLI.add_string("stream_id")
        |> CLI.add_string("h", "1")
        |> send_template(:stream_mgmt_resume, ~w[ h stream_id ]a)
        |> check!(:stream_mgmt_resumed)

      %{"stream_mgmt" => "enable"} = data ->
        data
        |> send_template(:bind, ~w[ resource ]a)
        |> check!(:bind)
        |> send_template(:stream_mgmt_enable)
        |> check!(:stream_mgmt_enabled)

      data ->
        data
        |> send_template(:bind, ~w[ resource ]a)
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
