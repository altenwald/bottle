defmodule Bottle.Checks do
  @moduledoc """
  Establish a trace for a specific client and trace all of the
  events from the client.
  """
  use GenServer

  alias Exampple.Router.Conn

  @default_max_events 50

  defstruct monitor_ref: nil,
            max_events: @default_max_events,
            events: [],
            wait_list: %{}

  @type event() :: {atom(), pid(), Keyword.t()}

  @type options() :: Keyword.t()

  @type check_name() :: atom()
  @type check_function() :: ((event(), options()) -> any() | no_return())

  @type t() :: %__MODULE__{
    monitor_ref: reference() | nil,
    max_events: pos_integer() | :infinity,
    events: [Conn.t()],
    wait_list: %{ GenServer.from() => {reference(), check_name(), options()} }
  }

  @doc """
  Start a process for handle the checks for a client process. We have
  to provide the name we want to provide for this process, the client
  where we are going to bind these checks and optionally the max number
  of events we want this process keep in its memory.

  The max number of events is configured by default to 50, if a new
  event arrives, the oldest is removed. This way if we are not using
  some events, they are gone little by little avoiding leaks of memory.
  If you need to create hundreds of clients, maybe you need to recheck
  the amount of events that should be stored.
  """
  def start_link(name, client, max_events \\ @default_max_events) do
    GenServer.start_link(__MODULE__, [client, max_events], name: name)
  end

  @doc """
  Ensure the checks are loaded from the checks file.
  """
  defdelegate setup(checks_path_file), to: Bottle.Checks.Storage

  @doc """
  Stop the process which is responsible of the checks for a client.
  """
  def stop(name) do
    GenServer.stop(name)
  end

  @doc """
  Stores a check inside of the storage shared for all of the checks.
  See `Bottle.Checks.Storage` for further information.
  """
  defdelegate put(key, value), to: Bottle.Checks.Storage

  @doc """
  Retrieves a check from the storage based on its `key`.
  See `Bottle.Checks.Storage` for further information.
  """
  defdelegate get(key), to: Bottle.Checks.Storage

  @doc """
  Use a check from storage identified by the `key` against the events
  received at the moment. If we indicate a `timeout` it's applied
  against all of the next incoming events during the specific time
  it's actived returning correctly if it matchs or with an error
  otherwise.

  The `options` are mainly to be handled by the check, as second
  parameter, the only one it's handled by the system is `timeout`.
  The function defined as check should handle the event incoming
  as first parameter and the options as second parameter.
  """
  def validate(name, key, options \\ []) do
    GenServer.call(name, {:validate, key, options})
  end

  @doc """
  Remove all the events from the queue. Perfect for a fresh start.
  """
  def flush(name) do
    GenServer.cast(name, :flush)
  end

  @doc false
  @impl GenServer
  def init([client, max_events]) when is_atom(client) do
    init([Process.whereis(client), max_events])
  end

  def init([client_pid, max_events]) when is_pid(client_pid) do
    ref = Process.monitor(client_pid)
    Exampple.Client.trace(client_pid, true)
    {:ok, %__MODULE__{monitor_ref: ref, max_events: max_events}}
  end

  @impl GenServer
  def handle_cast(:flush, state) do
    {:noreply, %__MODULE__{state | events: []}}
  end

  @impl GenServer
  def handle_info({:DOWN, ref, :process, _pid, reason}, %__MODULE__{monitor_ref: ref} = state) do
    {:stop, reason, state}
  end

  def handle_info({:timeout, from}, %__MODULE__{wait_list: wait_list} = state) when is_map_key(wait_list, from) do
    GenServer.reply(from, {:error, :timeout})
    {:noreply, remove_from_wait_list(state, from)}
  end

  def handle_info({:timeout, _from}, state) do
    {:noreply, state}
  end

  def handle_info({event_name, pid, _data} = event, %__MODULE__{wait_list: []} = state) when is_atom(event_name) and is_pid(pid) do
    events = Enum.take([event | state.events], state.max_events)
    {:noreply, %__MODULE__{state | events: events}}
  end

  def handle_info({event_name, pid, _data} = event, %__MODULE__{wait_list: wait_list} = state) when is_atom(event_name) and is_pid(pid) do
    check =
      fn {from, {ref, check_name, options}}, nil ->
        f = get(check_name)
        try do
          result = f.(event, options)
          {:halt, %{from: from, ref: ref, result: result}}
        catch
          _kind, _value ->
            {:cont, nil}
        end
      end

    if wait_check = Enum.reduce_while(wait_list, nil, check) do
      Process.cancel_timer(wait_check.ref)
      GenServer.reply(wait_check.from, {:ok, {wait_check.result, event}})
      {:noreply, remove_from_wait_list(state, wait_check.from)}
    else
      events = Enum.take([event | state.events], state.max_events)
      {:noreply, %__MODULE__{state | events: events}}
    end
  end

  @impl GenServer
  def handle_call({:validate, key, options}, from, %__MODULE__{events: events} = state) do
    f = get(key)
    check =
      fn event, nil ->
        try do
          result = f.(event, options)
          {:halt, {result, event}}
        catch
          _kind, _value ->
            # Logger.debug("no match, or error (#{kind}): #{inspect(value)} #{inspect(__STACKTRACE__)}")
            {:cont, nil}
        end
      end

    with {:check, f} when f != nil <- {:check, f},
         {:event, nil} <- {:event, Enum.reduce_while(events, nil, check)},
         {:timeout, nil} <- {:timeout, options[:timeout]} do
      {:reply, {:error, :no_match}, state}
    else
      {:check, nil} ->
        {:reply, {:error, :check_not_found}, state}

      {:event, {result, event}} ->
        {:reply, {:ok, {result, event}}, %__MODULE__{state | events: events -- [event]}}

      {:timeout, time} when is_integer(time) ->
        ref = Process.send_after(self(), {:timeout, from}, time)
        wait_list = Map.put(state.wait_list, from, {ref, key, options})
        {:noreply, %__MODULE__{state | wait_list: wait_list}}

      {:timeout, :infinity} ->
        ref = :infinity
        wait_list = Map.put(state.wait_list, from, {ref, key, options})
        {:noreply, %__MODULE__{state | wait_list: wait_list}}
    end
  end

  defp remove_from_wait_list(%__MODULE__{wait_list: wait_list} = state, from) do
    %__MODULE__{state | wait_list: Map.delete(wait_list, from)}
  end
end
