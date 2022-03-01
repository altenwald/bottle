defmodule Bottle.Stats do
  @moduledoc """
  Receive events to measure the traffic accross the clients.
  """
  use GenServer

  alias Exampple.Router.Conn
  alias Exampple.Xml

  # keeping data for 6 hours
  @default_buckets 6 * 60

  defstruct connected: 0,
            connected_delta: 0,
            action_success: 0,
            action_success_delta: 0,
            action_failure: 0,
            action_failure_delta: 0,
            disconnected: 0,
            disconnected_delta: 0,
            message_sent: 0,
            message_sent_delta: 0,
            message_recv: 0,
            message_recv_delta: 0,
            iq_sent: 0,
            iq_sent_delta: 0,
            iq_recv: 0,
            iq_recv_delta: 0,
            presence_sent: 0,
            presence_sent_delta: 0,
            presence_recv: 0,
            presence_recv_delta: 0,
            total_sent: 0,
            total_sent_delta: 0,
            total_recv: 0,
            total_recv_delta: 0,
            buckets_num: @default_buckets,
            buckets: []

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def get_buckets do
    GenServer.call(__MODULE__, :get_buckets)
  end

  def add_client(client) do
    GenServer.cast(__MODULE__, {:add_client, client})
  end

  def notify(event_name, action_module, data) when is_atom(action_module) do
    GenServer.cast(__MODULE__, {:notify, event_name, action_module, data})
  end

  @impl GenServer
  @spec init(Keyword.t()) :: {:ok, %__MODULE__{}}
  def init(opts) do
    Process.send_after(self(), :tick, 60_000)
    {:ok, %__MODULE__{buckets_num: opts[:buckets] || @default_buckets}}
  end

  @impl GenServer
  def handle_cast({:notify, event_name, _action_module, data}, state) do
    {:noreply, update_stats(state, event_name, data)}
  end

  def handle_cast({:add_client, client}, state) do
    :ok = Exampple.Client.trace(client, true)
    {:noreply, state}
  end

  defp update_stats(state, :action_success, _data) do
    %__MODULE__{state |
      action_success: state.action_success + 1,
      action_success_delta: state.action_success_delta + 1
    }
  end

  defp update_stats(state, :action_failure, _data) do
    %__MODULE__{state |
      action_failure: state.action_failure + 1,
      action_failure_delta: state.action_failure_delta + 1
    }
  end

  defp update_stats(state, :received, %Conn{stanza_type: "message"}) do
    %__MODULE__{state |
      message_recv: state.message_recv + 1,
      total_recv: state.total_recv + 1,
      message_recv_delta: state.message_recv_delta + 1,
      total_recv_delta: state.total_recv_delta + 1
    }
  end

  defp update_stats(state, :received, %Conn{stanza_type: "iq"}) do
    %__MODULE__{state |
      iq_recv: state.iq_recv + 1,
      total_recv: state.total_recv + 1,
      iq_recv_delta: state.iq_recv_delta + 1,
      total_recv_delta: state.total_recv_delta + 1
    }
  end

  defp update_stats(state, :received, %Conn{stanza_type: "presence"}) do
    %__MODULE__{state |
      presence_recv: state.presence_recv + 1,
      total_recv: state.total_recv + 1,
      presence_recv_delta: state.presence_recv_delta + 1,
      total_recv_delta: state.total_recv_delta + 1
    }
  end

  defp update_stats(state, :sent, %Conn{stanza_type: "message"}) do
    %__MODULE__{state |
      message_sent: state.message_sent + 1,
      total_sent: state.total_sent + 1,
      message_sent_delta: state.message_sent_delta + 1,
      total_sent_delta: state.total_sent_delta + 1
    }
  end

  defp update_stats(state, :sent, %Conn{stanza_type: "iq"}) do
    %__MODULE__{state |
      iq_sent: state.iq_sent + 1,
      total_sent: state.total_sent + 1,
      iq_sent_delta: state.iq_sent_delta + 1,
      total_sent_delta: state.total_sent_delta + 1
    }
  end

  defp update_stats(state, :sent, %Conn{stanza_type: "presence"}) do
    %__MODULE__{state |
      presence_sent: state.presence_sent + 1,
      total_sent: state.total_sent + 1,
      presence_sent_delta: state.presence_sent_delta + 1,
      total_sent_delta: state.total_sent_delta + 1
    }
  end

  defp update_stats(state, :connected, _event_data) do
    %__MODULE__{state |
      connected: state.connected + 1,
      connected_delta: state.connected_delta + 1
    }
  end

  defp update_stats(state, :disconnected, _event_data) do
    %__MODULE__{state |
      disconnected: state.disconnected + 1,
      disconnected_delta: state.disconnected_delta + 1
    }
  end

  defp update_stats(state, _event_name, _event_data) do
    state
  end

  @impl GenServer
  def handle_info({event_name, _pid, data}, state) do
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

    {:noreply, update_stats(state, event_name, conn)}
  end

  def handle_info(:tick, state) do
    state =
      state
      |> create_bucket()
      |> reset_deltas()

    Process.send_after(self(), :tick, 60_000)
    {:noreply, state}
  end

  defp get_deltas(state) do
    %{
      timestamp: System.os_time(),
      action_success: state.action_success_delta,
      action_failure: state.action_failure_delta,
      connected: state.connected_delta,
      disconnected: state.disconnected_delta,
      message_sent: state.message_sent_delta,
      message_recv: state.message_recv_delta,
      iq_sent: state.iq_sent_delta,
      iq_recv: state.iq_recv_delta,
      presence_sent: state.presence_sent_delta,
      presence_recv: state.presence_recv_delta,
      total_sent: state.total_sent_delta,
      total_recv: state.total_recv_delta
    }
  end

  defp get_global(state) do
    %{
      timestamp: System.os_time(),
      action_success: state.action_success,
      action_failure: state.action_failure,
      connected: state.connected,
      disconnected: state.disconnected,
      message_sent: state.message_sent,
      message_recv: state.message_recv,
      iq_sent: state.iq_sent,
      iq_recv: state.iq_recv,
      presence_sent: state.presence_sent,
      presence_recv: state.presence_recv,
      total_sent: state.total_sent,
      total_recv: state.total_recv
    }
  end

  defp create_bucket(%__MODULE__{buckets: buckets, buckets_num: buckets_num} = state) do
    bucket = get_deltas(state)
    %__MODULE__{state | buckets: Enum.slice([bucket | buckets], 0..(buckets_num - 1))}
  end

  defp reset_deltas(%__MODULE__{} = state) do
    %__MODULE__{ state |
      connected_delta: 0,
      disconnected_delta: 0,
      action_success_delta: 0,
      action_failure_delta: 0,
      message_sent_delta: 0,
      message_recv_delta: 0,
      iq_sent_delta: 0,
      iq_recv_delta: 0,
      presence_sent_delta: 0,
      presence_recv_delta: 0,
      total_sent_delta: 0,
      total_recv_delta: 0
    }
  end

  @impl GenServer
  def handle_call(:get_buckets, _from, state) do
    current_bucket = get_deltas(state)
    {:reply, [current_bucket | state.buckets], state}
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, get_global(state), state}
  end
end
