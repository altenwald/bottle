defmodule Bottle.Bot.Storage do
  alias Exampple.Xmpp.Jid

  def setup do
    if :ets.info(__MODULE__) == :undefined do
      __MODULE__ = :ets.new(__MODULE__, [:named_table, :set, :public])
    end
  end

  def put(pid, jid) when is_binary(jid) and is_pid(pid) do
    :ets.insert(__MODULE__, {pid, jid})
  end

  def put(pid, %Jid{} = jid) when is_pid(pid) do
    put(pid, to_string(jid))
  end

  def get(nil), do: nil

  def get(name) when is_atom(name) do
    get(Process.whereis(name))
  end

  def get(pid) when is_pid(pid) do
    case :ets.lookup(__MODULE__, pid) do
      [{^pid, jid}] -> jid
      [] -> nil
    end
  end
end
