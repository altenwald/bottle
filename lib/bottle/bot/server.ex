defmodule Bottle.Bot.Server do
  @moduledoc """
  The server is the process running which is using the behaviour defined
  by `Bottle.Bot`.
  """
  use GenServer

  require Logger

  @registry Bottle.Bot.Server.Registry

  @tick_time 250
  @max_tick_timeout 2_000
  @min_tick_timeout 150

  defp via(name) do
    {:via, Registry, {@registry, name}}
  end

  def start_link(name, module_name) when is_atom(module_name) do
    Registry.start_link(keys: :unique, name: @registry)
    GenServer.start_link(__MODULE__, [name, module_name], name: via(name))
  end

  def stop(name) do
    GenServer.stop(via(name))
  end

  @impl GenServer
  @doc false
  def init([name, module_name]) do
    Logger.metadata([name: name])
    Process.send_after(self(), :tick, @tick_time)
    Logger.notice("connecting #{name}")
    data =
      module_name.data()
      |> Bottle.Client.connect()

    {:ok, {module_name, data, module_name.actions()}}
  end

  @impl GenServer
  def handle_info(:tick, {module_name, _data, []}) do
    {:stop, :normal, module_name}
  end
  def handle_info(:tick, {module_name, data, [statement|statements]}) do
    case run_bot(statement, data) do
      {new_statement, data, timeout} ->
        Process.send_after(self(), :tick, timeout)
        {:noreply, {module_name, data, [new_statement|statements]}}

      {data, timeout} ->
        Process.send_after(self(), :tick, timeout)
        {:noreply, {module_name, data, statements}}
    end
  end

  defp run_bot({options, steps}, data) when is_list(options) and is_list(steps) do
    case {options[:for] || {:times, 1}, options[:as] || :ordered} do
      {{:times, 0}, _} ->
        {data, 0}

      {{:times, n}, :ordered} ->
        data = Enum.reduce(1..n, data, &run_steps(&2, &1, steps))
        {data, @tick_time}

      {{:times, n}, :random} ->
        steps = Enum.shuffle(steps)
        data = Enum.reduce(1..n, data, &run_steps(&2, &1, steps))
        {data, @tick_time}

      {{:times, n}, :chaotic} ->
        statement = {[times: n - 1, as: :chaotic], steps}
        data = run_steps(data, n, [Enum.random(steps)])
        timeout = Enum.random(@min_tick_timeout..@max_tick_timeout)
        {statement, data, timeout}
    end
  end

  defp run_steps(data, _i, []), do: data

  defp run_steps(data, i, [{name, options, actions}|steps]) do
    Logger.notice("running step #{name} (iteration #{i})")
    try do
      data
      |> run_actions(options[:optional] || false, actions)
      |> run_steps(i, steps)
    catch
      {:checking, action_name, error} ->
        Logger.warn("failed step #{name} in action #{action_name} (optional): #{inspect(error)}")
        data
    end
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

  defp run_actions(data, _optional, []), do: data

  defp run_actions(data, optional, [{__MODULE__, :wait_for, [name, timeout]}|actions]) when is_atom(name) and is_integer(timeout) and timeout > 0 do
    wait_for(optional, name, timeout)
    run_actions(data, optional, actions)
  end

  defp run_actions(data, optional, [{__MODULE__, :sending, [name, keywords]}|actions]) when is_atom(name) and is_list(keywords) do
    values = Keyword.values(keywords)
    data
    |> Bottle.Client.send_template(name, values)
    |> run_actions(optional, actions)
  end

  defp run_actions(data, false, [{__MODULE__, :checking, [name]}|actions]) when is_atom(name) do
    data
    |> Bottle.Client.check!(name)
    |> run_actions(false, actions)
  end
  defp run_actions(data, true, [{__MODULE__, :checking, [name]}|actions]) when is_atom(name) do
    try do
      data
      |> Bottle.Client.check!(name)
      |> run_actions(true, actions)
    rescue
      e in RuntimeError ->
        throw({:checking, name, e})
    end
  end

  defp run_actions(data, optional, [{module, function, args}|actions]) when module != __MODULE__ do
    apply(module, function, [data|args])
    |> run_actions(optional, actions)
  end
end
