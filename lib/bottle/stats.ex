defmodule Bottle.Stats do
  @moduledoc """
  Receive events to measure the traffic accross the clients.
  """
  use GenServer

  alias Bottle.Stats.Bucket
  alias Exampple.Router.Conn
  alias Exampple.Xml

  @pname {:global, __MODULE__}

  # keeping data for 6 hours
  @default_buckets 6 * 60

  # every 60 seconds a new bucket is created
  @default_tick_time 60_000

  defstruct current: [],
            subscribers: [],
            buckets_num: @default_buckets,
            buckets: [],
            tick_time: @default_tick_time

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @pname)
  end

  def get_stats(node \\ :global) do
    GenServer.call(@pname, {:get_stats, node})
  end

  def get_buckets(node \\ :global) do
    GenServer.call(@pname, {:get_buckets, node})
  end

  def subscribe, do: GenServer.cast(@pname, {:subscribe, self()})

  def unsubscribe, do: GenServer.cast(@pname, {:unsubscribe, self()})

  def wait_message(time) do
    receive do
      {:bucket, bucket} -> bucket
    after time ->
      nil
    end
  end

  def add_client(client) do
    GenServer.cast(@pname, {:add_client, client, node()})
  end

  def notify(event_name, action_module, data) when is_atom(action_module) do
    GenServer.cast(@pname, {:notify, self(), event_name, action_module, data})
  end

  @impl GenServer
  @spec init(Keyword.t()) :: {:ok, %__MODULE__{}}
  def init(opts) do
    tick_time = opts[:tick_time] || @default_tick_time
    Process.send_after(self(), :tick, tick_time)
    {:ok, %__MODULE__{
      buckets_num: opts[:buckets] || @default_buckets,
      current: %{ :global => Bucket.new(), node() => Bucket.new() },
      tick_time: tick_time
    }}
  end

  @impl GenServer
  def handle_cast({:notify, pid, event_name, _action_module, data}, state) do
    current = state.current
    global = Bucket.update(current[:global], event_name, data)
    local = Bucket.update(current[node(pid)], event_name, data)
    current = Map.merge(current, %{:global => global, node(pid) => local})
    {:noreply, %__MODULE__{state | current: current}}
  end

  def handle_cast({:add_client, client, node}, state) do
    :ok = Exampple.Client.trace({client, node}, true)
    current = Map.put_new(state.current, node, Bucket.new())
    {:noreply, %__MODULE__{state | current: current}}
  end

  def handle_cast({:subscribe, pid}, %__MODULE__{subscribers: pids} = state) do
    {:noreply, %__MODULE__{state | subscribers: [pid | pids]}}
  end

  def handle_cast({:unsubscribe, pid}, %__MODULE__{subscribers: pids} = state) do
    {:noreply, %__MODULE__{state | subscribers: pids -- [pid]}}
  end

  @impl GenServer
  def handle_info({event_name, pid, data}, state) do
    conn =
      with conn when is_nil(conn) <- data[:conn],
           packet when packet != nil <- data[:packet],
           false <- String.starts_with?(packet, "<?xml"),
           conn <- Conn.new(Xml.to_xmlel(packet)) do
        conn
      else
        true -> nil
        other -> other
      end

    current = state.current
    global = Bucket.update(current[:global], event_name, conn)
    local = Bucket.update(current[node(pid)], event_name, conn)
    current = Map.merge(current, %{:global => global, node(pid) => local})
    {:noreply, %__MODULE__{state | current: current}}
  end

  def handle_info(:tick, state) do
    state =
      state
      |> snapshot_bucket()
      |> reset_deltas()

    Process.send_after(self(), :tick, state.tick_time)
    send_bucket(state.subscribers, hd(state.buckets))
    {:noreply, state}
  end

  defp send_bucket([], _bucket), do: :ok

  defp send_bucket([pid | pids], bucket) do
    send(pid, {:bucket, bucket})
    send_bucket(pids, bucket)
  end

  defp reset_deltas(%__MODULE__{current: current} = state) do
    current =
      for {key, bucket} <- current, into: %{} do
        {key, Bucket.reset_deltas(bucket)}
      end

    %__MODULE__{state | current: current}
  end

  defp snapshot_bucket(%__MODULE__{buckets: buckets, buckets_num: buckets_num} = state) do
    bucket =
      for {key, bucket} <- state.current, into: %{} do
        {key, Bucket.get_deltas(bucket)}
      end

    %__MODULE__{state | buckets: Enum.slice([bucket | buckets], 0..(buckets_num - 1))}
  end

  @impl GenServer
  def handle_call({:get_buckets, node}, _from, state) do
    current_bucket = Bucket.get_deltas(state.current[node])
    buckets = Enum.map(state.buckets, & &1[node])
    {:reply, [current_bucket | buckets], state}
  end

  def handle_call({:get_stats, node}, _from, state) do
    {:reply, Bucket.get(state.current[node] || Bucket.new()), state}
  end
end
