defmodule Bottle do
  @moduledoc """
  Bottle is a Bot for XMPP designed to run a script based on Elixir
  scripting format (exs).

  The facilities Bottle gives to create scenarios
  """

  @green IO.ANSI.green()
  @red IO.ANSI.red()
  @purple IO.ANSI.magenta()
  @yellow IO.ANSI.yellow()
  @reset IO.ANSI.reset()

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

  def main(args) do
    opts = [
      switches: [
        buckets: :integer,
        "checks-file": :string,
        quiet: :boolean,
        "templates-file": :string,
        help: :boolean
      ],
      aliases: [
        b: :buckets,
        c: :"checks-file",
        q: :quiet,
        t: :"templates-file",
        h: :help
      ]
    ]
    case OptionParser.parse(args, opts) do
      {switches, [file], []} ->
        if working_dir = switches[:"working-dir"] do
          File.cd!(working_dir)
        end
        Bottle.Template.setup(switches[:"templates-file"] || "templates.exs")
        Bottle.Checks.setup(switches[:"checks-file"] || "checks.exs")
        Bottle.Bot.setup()
        unless switches[:quiet], do: {:ok, _} = Bottle.Logger.start_link()
        {:ok, _} = Bottle.Code.start_link([])
        {:ok, _} = Bottle.Stats.start_link(buckets: switches[:buckets] || (6 * 60))
        Code.eval_file(file)
        :ok

      {[{:help, true} | _], [], []} ->
        help()

      _ ->
        IO.puts("Unknown parameters")
        help()
    end
  end

  def distrib(local_node, cookie \\ :bottle, remote_nodes) do
    {:ok, _pid} = Node.start(local_node)
    true = Node.set_cookie(cookie)
    Enum.each(remote_nodes, fn remote_node ->
      {:ok, _pid} = Bottle.Remote.start_link(remote_node)
    end)
    :ok
  end

  def show_stats(time, line \\ 10) do
    show_stats(time, 0, line)
  end

  defp show_stats(time, 0, max_line) do
    print_stats_header()
    show_stats(time, max_line, max_line)
  end

  defp show_stats(time, line, max_line) do
    Process.sleep(time)
    Bottle.Stats.get_stats()
    |> print_stats()
    show_stats(time, line - 1, max_line)
  end

  defp print_stats_header do
    IO.puts("""
    +------+----------+----------+----------+----------+----------+----------+----------+----------+
    | type | messages | presence |   iqs    |  total   | connectd | disconn. |  act.ok  | act.fail |
    +------+----------+----------+----------+----------+----------+----------+----------+----------+
    """ |> String.trim_trailing())
  end

  defp num(stat, color) do
    stat
    |> to_string()
    |> String.pad_leading(8)
    |> String.replace_prefix("", color)
    |> String.replace_suffix("", @reset)
  end

  defp print_stats(stats) do
    data =
      "| #{@green}sent#{@reset} | " <>
        num(stats.message_sent, @green) <> " | " <>
        num(stats.presence_sent, @green) <> " | " <>
        num(stats.iq_sent, @green) <> " | " <>
        num(stats.total_sent, @green) <> " | " <>
        num(stats.connected, @purple) <> " | " <>
        num(stats.disconnected, @yellow) <> " | " <>
        num(stats.action_success, @green) <> " | " <>
        num(stats.action_failure, @red) <> " |\n" <>
        "| #{@red}recv#{@reset} | " <>
        num(stats.message_recv, @red) <> " | " <>
        num(stats.presence_recv, @red) <> " | " <>
        num(stats.iq_recv, @red) <> " | " <>
        num(stats.total_recv, @red) <> " | " <>
        String.duplicate(" ", 8) <> " | " <>
        String.duplicate(" ", 8) <> " | " <>
        String.duplicate(" ", 8) <> " | " <>
        String.duplicate(" ", 8) <> " |"

    IO.puts(data)
  end

  defp help do
    IO.puts """
    Bottle v#{Application.spec(:bottle)[:vsn]}

    Syntax: bottle [-w <dir>] [-c <file>] [-t <file>] [-q] [-h] file.exs

    Parameters:
      -b | --buckets N                Stats storage 1 bucket = 1 min.
      -c | --checks-file FILE         File to load the checks.
      -q | --quiet                    Don't show details (stanzas).
      -t | --templates-file FILE      File to load the templates.
      -h | --help                     Shows this message.
      file.exs                        File to be processed.
    """
  end
end
