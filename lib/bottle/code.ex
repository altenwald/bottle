defmodule Bottle.Code do
  use GenServer

  @types ~w[ bot action ]a
  @pname {:global, __MODULE__}

  defstruct bots: %{},
            actions: %{}

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: @pname)
  end

  def register(code, module, type) when is_atom(module) and type in @types do
    GenServer.cast(@pname, {:register, code, module, type})
  end

  def get(type, module) when type in @types and is_atom(module) do
    GenServer.call(@pname, {:get, type, module})
  end

  def get_all(type) when type in @types do
    GenServer.call(@pname, {:get_all, type})
  end

  def get_all do
    GenServer.call(@pname, :get_all)
  end

  def compile(type, module) do
    code = get(type, module)
    {result, _bindings} = Code.eval_quoted(code)
    {module, result}
  end

  def compile do
    compile(get_all())
  end

  def compile(mapcode) do
    for {module, code} <- mapcode do
      {result, _bindings} = Code.eval_quoted(code) |> IO.inspect(label: "compiling #{module}")
      {module, result}
    end
  end

  @impl GenServer
  def init([]) do
    {:ok, %__MODULE__{}}
  end

  @impl GenServer
  def handle_cast({:register, code, module, :bot}, state) do
    {:noreply, %__MODULE__{state | bots: Map.put(state.bots, module, code)}}
  end

  def handle_cast({:register, code, module, :action}, state) do
    {:noreply, %__MODULE__{state | actions: Map.put(state.actions, module, code)}}
  end

  @impl GenServer
  def handle_call({:get, :bot, module}, _from, state) do
    {:reply, Map.get(state.bots, module), state}
  end

  def handle_call({:get_all, :bot}, _from, state) do
    {:reply, state.bots, state}
  end

  def handle_call({:get, :action, module}, _from, state) do
    {:reply, Map.get(state.actions, module), state}
  end

  def handle_call({:get_all, :action}, _from, state) do
    {:reply, state.actions, state}
  end

  def handle_call(:get_all, _from, state) do
    {:reply, Map.merge(state.actions, state.bots), state}
  end
end
