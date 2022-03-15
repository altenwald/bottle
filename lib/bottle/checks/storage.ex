defmodule Bottle.Checks.Storage do
  @moduledoc """
  Storage for the checks and ensure all of the check processes
  have access to the same checks.
  """
  alias Bottle.Checks
  alias Exampple.Router.Conn
  alias Exampple.Xml.Xmlel

  @doc """
  Starts the storage and loads the information from the file passed
  as parameter.
  """
  @spec setup(String.t()) :: :ok
  def setup(checks_file_path) do
    if :ets.info(__MODULE__) == :undefined do
      __MODULE__ = :ets.new(__MODULE__, [:named_table, :set, :public])
      for {key, fun} <- default_checks(), do: put(key, fun)
      for {key, fun} <- Bottle.get_checks(checks_file_path), do: put(key, fun)
    end
    :ok
  end

  def init do
    if :ets.info(__MODULE__) == :undefined do
      __MODULE__ = :ets.new(__MODULE__, [:named_table, :set, :public])
    end
  end

  @spec put(Checks.check_name(), Checks.check_function()) :: :ok
  def put(key, fun) do
    true = :ets.insert(__MODULE__, {key, fun})
    :ok
  end

  @spec put([{Checks.check_name(), Checks.check_function()}]) :: :ok
  def put(checks) do
    :ets.insert(__MODULE__, checks)
    :ok
  end

  @spec get(Checks.check_name()) :: Checks.check_function() | nil
  def get(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, fun}] -> fun
      [] -> nil
    end
  end

  @spec get() :: [{Checks.check_name(), Checks.check_function()}]
  def get do
    :ets.tab2list(__MODULE__)
  end

  defp default_checks do
    [
      starttls: fn {:received, _pid, data}, _opts ->
        %Conn{stanza_type: "proceed"} = data[:conn]
      end,
      features: fn {:received, _pid, data}, _opts ->
        %Conn{
          stanza_type: "stream:features",
          stanza: stanza
        } = data[:conn]
        [%Xmlel{name: "mechanisms"} = mech] = stanza["mechanisms"]
        true = %Xmlel{name: "mechanism", children: ["PLAIN"]} in mech["mechanism"]
        [%Xmlel{name: "register"}] = stanza["register"]
        data[:conn]
      end,
      auth: fn {:received, _pid, data}, _opts ->
        %Conn{stanza_type: "success"} = data[:conn]
      end,
      init: fn {:received, _pid, data}, _opts ->
        %Conn{stanza_type: "stream:features", stanza: stanza, xmlns: "urn:ietf:params:xml:ns:xmpp-bind"} = data[:conn]
        [%Xmlel{}] = stanza["bind"]
        [%Xmlel{}] = stanza["session"]
        data[:conn]
      end,
      stream_mgmt_resumed: fn {:received, _pid, data}, _opts ->
        %Conn{stanza_type: "resumed"} = data[:conn]
      end,
      stream_mgmt_enabled: fn {:received, _pid, data}, _opts ->
        %Conn{stanza_type: "enabled", stanza: %Xmlel{attrs: attrs}} = conn = data[:conn]

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
      bind: fn {:received, _pid, data}, _opts ->
        %Conn{stanza_type: "iq", type: "result", xmlns: "urn:ietf:params:xml:ns:xmpp-bind"} = data[:conn]
      end,
      presence: fn {:received, _pid, data}, _opts ->
        %Conn{stanza_type: "presence", type: "available"} = data[:conn]
      end
    ]
  end
end
