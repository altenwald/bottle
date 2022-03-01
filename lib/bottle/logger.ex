defmodule Bottle.Logger do
  use GenServer

  @green IO.ANSI.green()
  @red IO.ANSI.red()
  @reset IO.ANSI.reset()

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def add_client(client) do
    GenServer.cast(__MODULE__, {:add_client, client})
  end

  def info(name, message) when is_pid(name) do
    info("#{inspect(name)}", message)
  end

  def info(name, message) do
    GenServer.cast(__MODULE__, {:info, name, message})
  end

  def error(name, message) when is_pid(name) do
    error("#{inspect(name)}", message)
  end

  def error(name, message) do
    GenServer.cast(__MODULE__, {:error, name, message})
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

  def handle_cast({:add_client, client}, state) do
    :ok = Exampple.Client.trace(client, true)
    pid = Process.whereis(client)
    _ref = Process.monitor(pid)
    {:noreply, Map.put(state, pid, client)}
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
    name = state[pid] || pid
    print :received, name, to_string(data[:conn].stanza)
    {:noreply, state}
  end

  def handle_info({:sent, pid, data}, state) do
    name = state[pid] || pid
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
