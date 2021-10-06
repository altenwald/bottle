defmodule Bottle.Bot.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      Bottle.Bot.Stats,
      {DynamicSupervisor, strategy: :one_for_one, name: Bottle.Bot.Servers}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_child(name, module_name) do
    DynamicSupervisor.start_child(Bottle.Bot.Servers, {Bottle.Bot.Server, [name, module_name]})
  end
end
