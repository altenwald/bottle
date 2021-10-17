defmodule Bottle.Bot.Runner do
  @moduledoc """
  The runner is the process in charge to store the running script for the
  bot and the bot server.
  """
  use GenServer

  require Logger

  @tick_time 250
  @max_tick_timeout 2_000
  @min_tick_timeout 150

  def start_link(module_name) when is_atom(module_name) do
    GenServer.start_link(__MODULE__, [module_name])
  end

  defdelegate stop(pid), to: GenServer

  def get_statement(pid) do
    GenServer.call(pid, :get_statement)
  end

  def skip(pid) do
    GenServer.call(pid, :skip)
  end

  @impl GenServer
  @doc false
  def init([module_name]) do
    {:ok, {[], module_name.actions()}}
  end

  @impl GenServer
  def handle_call(:get_statement, _from, {[], []}) do
    {:stop, :normal, :eos, []}
  end
  def handle_call(:get_statement, from, {[], [statement|statements]}) do
    handle_call(:get_statement, from, {run_bot(statement), statements})
  end
  def handle_call(:get_statement, _from, {[command|commands], statements}) do
    {:reply, command, {commands, statements}}
  end
  def handle_call(:skip, _from, {[], _statements} = state) do
    {:reply, :ok, state}
  end
  def handle_call(:skip, _from, {[{_, name, _, _, _, _, _}|commands], statements}) do
    commands = Enum.drop_while(commands, fn {_, n, _, _, _, _, _} -> n == name end)
    {:reply, :ok, {commands, statements}}
  end

  defp run_bot({options, steps}) when is_list(options) and is_list(steps) do
    case {options[:for] || {:times, 1}, options[:as] || :ordered} do
      {{:times, 0}, _} ->
        []

      {{:times, n}, :ordered} ->
        Enum.reduce(1..n, [], &run_steps(&2, &1, @tick_time, steps))

      {{:times, n}, :random} ->
        steps = Enum.shuffle(steps)
        Enum.reduce(1..n, [], &run_steps(&2, &1, @tick_time, steps))

      {{:times, n}, :chaotic} ->
        Enum.reduce(1..n, [], fn _, acc ->
          timeout = Enum.random(@min_tick_timeout..@max_tick_timeout)
          run_steps(acc, n, timeout, [Enum.random(steps)])
        end)
    end
  end

  defp run_steps(statements, _i, _timeout, []), do: statements

  defp run_steps(statements, i, timeout, [{name, options, actions}|steps]) do
    statements
    |> run_actions(options[:optional] || false, name, i, timeout, actions)
    |> run_steps(i, timeout, steps)
  end

  defp run_actions(statements, _optional, _name, _i, _timeout, []), do: statements

  defp run_actions(statements, optional, sname, i, stimeout, [{__MODULE__, :wait_for, [name, timeout]}|actions]) when is_atom(name) and is_integer(timeout) and timeout > 0 do
    statements = statements ++ [{:wait_for, sname, i, optional, name, [], timeout}]
    run_actions(statements, optional, sname, i, stimeout, actions)
  end

  defp run_actions(statements, optional, sname, i, timeout, [{module, function, args}|actions]) when module != __MODULE__ do
    statements = statements ++ [{:apply, sname, i, optional, {module, function, args}, [], timeout}]
    run_actions(statements, optional, sname, i, timeout, actions)
  end
end
