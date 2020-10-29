import Bottle
import Bottle.Client
alias Exampple.Client

IEx.configure([
  default_prompt: "#{IO.ANSI.green()}bottle#{IO.ANSI.reset()}(#{IO.ANSI.blue()}%counter#{IO.ANSI.reset()})> "
])

IO.puts(
  "\n" <>
  "#{IO.ANSI.color(0, 0, 0)}A" <>
  "#{IO.ANSI.color(1, 1, 1)}l" <>
  "#{IO.ANSI.color(2, 2, 2)}t" <>
  "#{IO.ANSI.color(2, 2, 2)}e" <>
  "#{IO.ANSI.color(3, 3, 3)}n" <>
  "#{IO.ANSI.color(3, 3, 3)}w" <>
  "#{IO.ANSI.color(3, 3, 3)}a" <>
  "#{IO.ANSI.color(4, 4, 4)}l" <>
  "#{IO.ANSI.color(4, 4, 4)}d" <>
  "#{IO.ANSI.reset()} Bottle #{Application.spec(:bottle)[:vsn]}\n"
)
