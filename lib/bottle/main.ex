defmodule Bottle.Main do
  @moduledoc """
  Main function which will be called from escript to start processing
  the actions or whatever needed.
  """

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
