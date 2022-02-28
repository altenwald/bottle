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
      import Bottle.{Client, Config}
      import Exampple.Xml.Xmlel

      alias Bottle.CLI
      alias Exampple.Xmpp.Stanza
    end
  end

  defmacro __using__(:bot) do
    quote do
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

  def main(args) do
    opts = [
      switches: [
        "checks-file": :string,
        "templates-file": :string,
        help: :boolean
      ],
      aliases: [
        c: :"checks-file",
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
        Bottle.Logger.start_link()
        Code.eval_file(file)
        :ok

      {[{:help, true} | _], [], []} ->
        help()

      _ ->
        IO.puts("Unknown parameters")
        help()
    end
  end

  defp help do
    IO.puts """
    Bottle v#{Application.spec(:bottle)[:vsn]}

    Syntax: bottle [-w <directory>] [-h] file.exs

    Parameters:
      -w | --working-dir <directory>  Changes the working directory.
      -h | --help                     Shows this message.
      file.exs                        File to be processed.
    """
  end
end
