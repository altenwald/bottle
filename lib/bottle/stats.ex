defmodule Bottle.Stats do
  use GenServer

  alias Exampple.Router.Conn

  defstruct connected: 0,
            disconnected: 0,
            message_sent: 0,
            message_recv: 0,
            iq_sent: 0,
            iq_recv: 0,
            presence_sent: 0,
            presence_recv: 0,
            total_sent: 0,
            total_recv: 0

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def add_client(client) do
    GenServer.cast(__MODULE__, {:add_client, client})
  end

  @impl GenServer
  def init([]) do
    {:ok, %__MODULE__{}}
  end

  @impl GenServer
  def handle_cast({:add_client, client}, state) do
    :ok = Exampple.Client.trace(client, true)
    {:noreply, state}
  end

  defp update_stats(state, :received, %Conn{stanza_type: "message"}) do
    %__MODULE__{state |
      message_recv: state.message_recv + 1,
      total_recv: state.total_recv + 1
    }
  end

  defp update_stats(state, :received, %Conn{stanza_type: "iq"}) do
    %__MODULE__{state |
      iq_recv: state.iq_recv + 1,
      total_recv: state.total_recv + 1
    }
  end

  defp update_stats(state, :received, %Conn{stanza_type: "presence"}) do
    %__MODULE__{state |
      presence_recv: state.presence_recv + 1,
      total_recv: state.total_recv + 1
    }
  end

  defp update_stats(state, :sent, %Conn{stanza_type: "message"}) do
    %__MODULE__{state |
      message_sent: state.message_sent + 1,
      total_sent: state.total_sent + 1
    }
  end

  defp update_stats(state, :sent, %Conn{stanza_type: "iq"}) do
    %__MODULE__{state |
      iq_sent: state.iq_sent + 1,
      total_sent: state.total_sent + 1
    }
  end

  defp update_stats(state, :sent, %Conn{stanza_type: "presence"}) do
    %__MODULE__{state |
      presence_sent: state.presence_sent + 1,
      total_sent: state.total_sent + 1
    }
  end

  defp update_stats(state, :connected, _event_data) do
    %__MODULE__{state | connected: state.connected + 1}
  end

  defp update_stats(state, :disconnected, _event_data) do
    %__MODULE__{state | disconnected: state.disconnected + 1}
  end

  defp update_stats(state, _event_name, _event_data) do
    state
  end

  @impl GenServer
  def handle_info({event_name, _pid, data}, state) do
    {:noreply, update_stats(state, event_name, data[:conn])}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    {:reply, Map.from_struct(state), state}
  end
end
