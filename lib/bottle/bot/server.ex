defmodule Bottle.Bot.Server do
  @moduledoc """
  The server is the process running which is using the behaviour defined
  by `Bottle.Bot`.
  """
  use GenStateMachine

  require Logger

  alias Bottle.Bot.Runner
  alias Exampple.Xmpp.Jid

  defstruct [
    name: nil,
    module_name: nil,
    data: %{},
    runner: nil,
    check_args: nil,
    check_optional: false
  ]

  @registry Bottle.Bot.Server.Registry

  @tick_time 250

  defp via(name) do
    {:via, Registry, {@registry, name}}
  end

  def start_link(name, module_name) when is_atom(module_name) do
    Registry.start_link(keys: :unique, name: @registry)
    GenStateMachine.start_link(__MODULE__, [name, module_name], name: via(name))
  end

  def stop(name) do
    GenStateMachine.stop(via(name))
  end

  def get_jid(name) do
    GenStateMachine.call(via(name), :get_jid)
  end

  @impl GenStateMachine
  @doc false
  def init([name, module_name]) do
    Logger.metadata([name: name])
    Logger.notice("connecting #{name}")
    data =
      module_name.data()
      |> Bottle.Client.connect()

    {:ok, runner} = Runner.start_link(module_name)
    actions = [{{:timeout, :tick}, @tick_time, :tick}]
    state = %__MODULE__{
      name: name,
      module_name: module_name,
      data: data,
      runner: runner
    }

    {:ok, :running, state, actions}
  end

  @impl GenStateMachine
  def handle_event({:timeout, :tick}, :tick, :running, statedata) do
    case Runner.get_statement(statedata.runner) do
      :eos ->
        Logger.info "(#{statedata.name}) stopping"
        {:stop, :normal, statedata}

      {:apply, name, i, optional, {__MODULE__, :checking, [_name, keywords] = args}, _keywords, tick_time} ->
        tick_time = keywords[:timeout] || tick_time
        Logger.info "(#{statedata.name}) step=#{name} i=#{i} t=#{tick_time}ms checking #{inspect(args)}"
        statedata = %__MODULE__{statedata|check_args: args, check_optional: optional}
        actions = [{:state_timeout, tick_time, :tick}]
        {:next_state, :checking, statedata, actions}

      {:apply, name, i, optional, {m, f, a}, _keywords, tick_time} ->
        Logger.info "(#{statedata.name}) step=#{name} i=#{i} t=#{tick_time}ms #{m}.#{f} #{inspect(a)}"
        data = apply_action(name, i, optional, {m, f, a}, statedata.data)
        statedata = %__MODULE__{statedata|data: data}
        actions = [{{:timeout, :tick}, tick_time, :tick}]
        {:keep_state, statedata, actions}
    end
  end

  def handle_event(:state_timeout, :tick, :checking, statedata) do
    if statedata.check_optional do
      :ok = Runner.skip(statedata.runner)
      actions = [{:next_event, {:timeout, :tick}, :tick}]
      {:next_state, :running, statedata, actions}
    else
      Logger.error("(#{statedata.data["process_name"]}) checking: #{inspect(statedata.check_args)}")
      {:stop, {:check!, statedata.check_args}, statedata}
    end
  end

  def handle_event(:info, {:conn, pname, conn}, :checking, %__MODULE__{data: %{"process_name" => pname}, check_args: [name, keywords]} = statedata) do
    try do
      result = Exampple.Client.check!(name, [pname, conn, keywords], pname)
      statedata = %__MODULE__{statedata|data: Map.merge(statedata.data, result)}
      actions = [{{:timeout, :tick}, @tick_time, :tick}]
      Logger.debug("(#{pname}) configuring tick #{@tick_time}ms")
      {:next_state, :running, statedata, actions}
    rescue
      error ->
        Logger.debug("(#{pname}) conn not expected (postponed): #{IO.ANSI.red()}#{to_string(conn.stanza)}#{IO.ANSI.reset()}")
        Logger.debug("(#{pname}) error: #{inspect(error)}")
        {:keep_state_and_data, [:postpone]}
    end
  end

  def handle_event(:info, {:conn, pname, conn}, :running, %_{data: %{"process_name" => pname}}) do
    Logger.debug("(#{pname}) conn not expected (postponed): #{IO.ANSI.red()}#{to_string(conn.stanza)}#{IO.ANSI.reset()}")
    {:keep_state_and_data, [:postpone]}
  end

  def handle_event({:call, from}, :get_jid, _state, %_{data: data}) do
    jid = Jid.new(data["user"], data["domain"], data["resource"])
    actions = [{:reply, from, jid}]
    {:keep_state_and_data, actions}
  end

  defp wait_for(true, name, timeout) when timeout <= 0 do
    throw({:wait_for, name})
  end
  defp wait_for(false, name, timeout) when timeout <= 0 do
    raise "client #{name} not available"
  end
  defp wait_for(optional, name, timeout) do
    unless Bottle.Client.is_connected?(%{"process_name" => name}) do
      Process.sleep(100)
      wait_for(optional, name, timeout - 100)
    end
  end

  defp apply_action(_sname, _i, optional, {__MODULE__, :wait_for, [name, timeout]}, data) when is_atom(name) and is_integer(timeout) and timeout > 0 do
    wait_for(optional, name, timeout)
    data
  end

  defp apply_action(_sname, _i, _optional, {__MODULE__, :sending, [name, keywords]}, %{"process_name" => pname} = data) when is_atom(name) and is_list(keywords) do
    origin_id = UUID.uuid4()
    Exampple.Client.send_template(name, [[{:origin_id, origin_id}|keywords]], pname)
    data
  end

  defp apply_action(_sname, _i, _optional, {module, function, args}, data) when module != __MODULE__ do
    apply(module, function, [data|args])
  end
end
