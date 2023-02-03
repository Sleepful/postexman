defmodule PXTest do
  use ExUnit.Case
  doctest PX

  test "greets the world" do
    assert PX.hello() == :world
  end
end
