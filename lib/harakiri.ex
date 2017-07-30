require Harakiri.Helpers, as: H
alias Harakiri, as: Hk

defmodule Harakiri do
  use Application

  @doc """
    Start and supervise a single lonely worker
  """
  def start(_,_) do
    import Supervisor.Spec

    # start ETS named_table from here,
    # thus make it persistent as long as the VM runs (Harakiri should be `permanent`...)
    :ets.new(:harakiri_table, [:public,:set,:named_table])

    loop_sleep_ms = H.env(:loop_sleep_ms, 5_000)

    opts = [strategy: :one_for_one, name: Hk.Supervisor]
    children = [ worker(Task, [Hk.Worker,:loop,[loop_sleep_ms]]) ]
    Supervisor.start_link(children, opts)
  end

  @doc """
    Add given `Map` as an `Harakiri.ActionGroup`.
    See README or tests for examples.
  """
  def add(data, opts \\ []) when is_map(data), do: data |> H.digest_data |> H.insert(opts)

  @doc """
    Run given `fun` or `action` when given `path` is touched.
  """
  def monitor(path, fun, opts \\ [])
  def monitor(path, fun, opts) when is_binary(path) and is_function(fun),
    do: %{paths: [path], action: fun} |> add(opts)
  def monitor(path, action, opts) when is_binary(path) and is_atom(action),
    do: %{paths: [path], action: action} |> add(opts)

  @doc """
    Get/set all Harakiri state
  """
  def state do
    :ets.tab2list(:harakiri_table)
    |> Enum.sort
    |> Enum.map(fn({_,ag})-> ag end)   # remove keys
  end
  def state(data), do: for( d <- data, do: :ok = H.upsert(d) )
end
