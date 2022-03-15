defmodule Bottle.Remote do
  use GenServer

  def start_link(remote_node) do
    GenServer.start_link(__MODULE__, [remote_node], name: remote_node)
  end

  @impl GenServer
  def init([remote_node]) do
    :pong = Node.ping(remote_node)

    [:exampple, :bottle, :gen_state_machine, :saxy, :uuid]
    |> Enum.map(&Application.spec(&1, :modules))
    |> List.flatten()
    |> Enum.each(fn module ->
      {^module, binary, filename} = :code.get_object_code(module)
      {:module, ^module} = :rpc.call(remote_node, :code, :load_binary, [module, filename, binary])
    end)

    templates = Exampple.Template.all()
    checks = Bottle.Checks.Storage.get()

    parent = self()
    pid =
      Node.spawn_link(remote_node, fn ->
        Application.ensure_all_started(:ssl)
        Bottle.Bot.setup()
        Exampple.Template.init()
        Exampple.Template.put(templates)
        Bottle.Checks.Storage.init()
        Bottle.Checks.Storage.put(checks)
        Bottle.Code.compile()
        send(parent, :sync)
        receive do :ok -> throw(:killed) end
      end)
    receive do :sync -> :ok end
    {:ok, pid}
  end
end
