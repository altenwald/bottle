defmodule BottleTest do
  use ExUnit.Case
  doctest Bottle

  test "greets the world" do
    assert Bottle.hello() == :world
  end
end
