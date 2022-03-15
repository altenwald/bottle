defmodule Bottle.Logger do
  use GenServer

  @green IO.ANSI.green()
  @red IO.ANSI.red()
  @reset IO.ANSI.reset()

  @pname {:global, __MODULE__}

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @pname)
  end

  def add_client(client) do
    GenServer.cast(@pname, {:add_client, client, node()})
  end

  def info(name, message) when is_pid(name) do
    info("#{inspect(name)}", message)
  end

  def info(name, message) do
    GenServer.cast(@pname, {:info, name, message})
  end

  def error(name, message) when is_pid(name) do
    error("#{inspect(name)}", message)
  end

  def error(name, message) do
    GenServer.cast(@pname, {:error, name, message})
  end

  @impl GenServer
  def init([]) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:info, name, msg}, state) do
    ts = to_string(NaiveDateTime.utc_now())
    IO.puts("#{ts} [#{name}] info: #{@green}#{msg}#{@reset}")
    {:noreply, state}
  end

  def handle_cast({:error, name, msg}, state) do
    ts = to_string(NaiveDateTime.utc_now())
    IO.puts("#{ts} [#{name}] error: #{@red}#{msg}#{@reset}")
    {:noreply, state}
  end

  def handle_cast({:add_client, client, node}, state) when node == node() do
    :ok = Exampple.Client.trace({client, node}, true)
    pid = Process.whereis(client)
    _ref = Process.monitor(pid)
    {:noreply, Map.put(state, pid, {client, node})}
  end

  def handle_cast({:add_client, client, remote_node}, state) do
    :ok = Exampple.Client.trace({client, remote_node}, true)
    pid = :rpc.call(remote_node, Process, :whereis, [client])
    _ref = Process.monitor(pid)
    {:noreply, Map.put(state, pid, {client, remote_node})}
  end

  defp print(:received, name, msg) do
    ts = to_string(NaiveDateTime.utc_now())
    IO.puts("#{ts} [#{name}] received: #{@green}#{msg}#{@reset}")
  end

  defp print(:sent, name, msg) do
    ts = to_string(NaiveDateTime.utc_now())
    IO.puts("#{ts} [#{name}] sent: #{@red}#{msg}#{@reset}")
  end

  @impl GenServer
  def handle_info({:received, pid, data}, state) do
    {name, _node} = state[pid] || pid
    print :received, name, to_string(data[:conn].stanza)
    {:noreply, state}
  end

  def handle_info({:sent, pid, data}, state) do
    {name, _node} = state[pid] || pid
    packet = data[:packet]
    if is_binary(packet) do
      print :sent, name, packet
    end
    {:noreply, state}
  end

  def handle_info({_event_name, _pid, _event_data}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, Map.delete(state, pid)}
  end
end
