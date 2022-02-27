defmodule Bottle.Bot.Registry do
  alias Exampple.Xmpp.Jid

  def setup do
    Registry.start_link(
      keys: :unique,
      name: __MODULE__,
      partitions: System.schedulers_online())
  end

  def put(jid) when is_binary(jid) do
    Registry.register(__MODULE__, jid, nil)
  end

  def put(%Jid{} = jid) do
    put(to_string(jid))
  end

  def get(nil), do: nil

  def get(name) when is_atom(name) do
    get(Process.whereis(name))
  end

  def get(pid) when is_pid(pid) do
    case Registry.keys(__MODULE__, pid) do
      [jid] -> jid
      [] -> nil
    end
  end
end
