defmodule Bottle do
  @moduledoc """
  Bottle is a Bot for XMPP designed to run a script based on Elixir
  scripting format (exs).

  The facilities Bottle gives to create scenarios
  """

  defmacro __using__(:checks) do
    quote do
      alias Exampple.Client
      require Exampple.Client
      alias Exampple.Router.Conn
      alias Exampple.Xml.Xmlel
    end
  end

  defmacro __using__(:scenario) do
    quote do
      import Bottle, only: [config: 1, distrib: 2, distrib: 3]
      import Bottle.{Client, Config}
      import Exampple.Xml.Xmlel

      alias Bottle.CLI
      alias Exampple.Xmpp.Stanza
    end
  end

  defmacro __using__(:bot) do
    quote do
      import Bottle, only: [config: 1, distrib: 2, distrib: 3]
      import Bottle.Action, except: [run: 2]
      import Bottle.Bot, except: [setup: 0]
      import Bottle.{Client, Config}
      import Exampple.Xml.Xmlel

      alias Bottle.CLI
      alias Exampple.Xmpp.Stanza
    end
  end

  defp eval(file, bindings) do
    if File.exists?(file) do
      {output, _out_bindings} =
        file
        |> File.read!()
        |> Code.eval_string(bindings, file: file)

      output
    else
      []
    end
  end

  def get_templates(filename, bindings \\ []) do
    eval(filename, bindings)
  end

  def get_checks(filename, bindings \\ []) do
    eval(filename, bindings)
  end

  defdelegate config(file), to: Bottle.Config, as: :read_file

  def distrib(local_node, cookie \\ :bottle, remote_nodes) do
    {:ok, _pid} = Node.start(local_node)
    true = Node.set_cookie(cookie)
    Enum.each(remote_nodes, fn remote_node ->
      {:ok, _pid} = Bottle.Remote.start_link(remote_node)
    end)
    :ok
  end

  def show_stats(time, opts) do
    header_every = opts[:header_every] || 5
    nodes = opts[:nodes] || Node.list([:connected, :this])
    show_stats(time, 0, header_every, nodes)
  end

  defp show_stats(time, 0, header_every, nodes) do
    Bottle.CLI.print_stats_header()
    show_stats(time, header_every, header_every, nodes)
  end

  defp show_stats(time, line, header_every, nodes) do
    Process.sleep(time)
    nodes
    |> Enum.map(&{&1, Bottle.Stats.get_stats(&1)})
    |> Enum.reject(fn {_, stats} -> is_nil(stats) end)
    |> case do
      [] ->
        Bottle.CLI.print_stats_banner("No data")

      [{_node, stats}] ->
        Bottle.CLI.print_stats(stats)

      all_stats ->
        for {node, stats} <- all_stats do
          Bottle.CLI.print_stats_node(node)
          Bottle.CLI.print_stats(stats)
        end
    end
    show_stats(time, line - 1, header_every, nodes)
  end
end
