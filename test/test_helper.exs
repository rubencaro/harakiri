ExUnit.start()

defmodule TestHelpers do

  @doc """
    Wait for given function to return true.
    Optional `msecs` and `step`.
  """
  def wait_for(func, msecs \\ 5_000, step \\ 100) do
    if func.() do
      :ok
    else
      if msecs <= 0, do: raise "Timeout!"
      :timer.sleep step
      wait_for func, msecs - step, step
    end
  end

end
