defmodule Harakiri do
  use Application

  @doc """
    Start and supervise a single lonely worker
  """
  def start(_,_) do
    import Supervisor.Spec, warn: false
    opts = [strategy: :one_for_one, name: Harakiri.Supervisor]
    Supervisor.start_link([worker(Harakiri.Worker, [])], opts)
  end
end

defmodule Harakiri.ActionGroup do
  defstruct paths: [], app: nil, action: nil, metadata: [loops: 0, hits: 0]
end

defmodule Harakiri.Worker do
  use GenServer
  alias Harakiri.ActionGroup

  @moduledoc """
    Start the harakiri loop for the files at given paths in a supervisable
    `GenServer`. If any of the files change, then the given action is fired.

    Actions can be:

    * `:stop`: `Application.stop/1` and `Application.unload/1` are called.
    * `:restart`: like `:stop` and then `Application.ensure_all_started/1`.

    Add an _action group_ like this:
    ```
    Harakiri.add paths: ["file1","file2"], app: :myapp, action: :restart
    ```
    You can pass an `ActionGroup` as well instead of a plain `Map`.
  """

  def start_link, do: GenServer.start_link(__MODULE__, :ok, name: :harakiri_server)

  @doc """
    Init callback, spawn the loop process and return the state
  """
  def init(:ok) do
    spawn_link fn -> loop(Application.get_env(:harakiri, :loop_sleep_ms, 5_000)) end
    {:ok, []}
  end

  @doc """
    Add given data as an _action group_. It should be a `Map`.
    ```
    Harakiri.add %{paths: ["file1","file2"], app: :myapp, action: :restart}
    ```
  """
  def add(data) when is_map(data) do
    data = %ActionGroup{} |> Map.merge data # put into an ActionGroup
    paths = for p <- data.paths, into: [] do
      [path: p, mtime: get_file_mtime(p)]
    end
    data = %{data | paths: paths}
    GenServer.call(:harakiri_server,{:add, data})
  end

  @doc """
    Get/set all Harakiri state
  """
  def state, do: GenServer.call(:harakiri_server,:state)
  def state(data), do: GenServer.call(:harakiri_server,{:state,data})

  @doc """
    Clear all Harakiri state
  """
  def clear, do: GenServer.call(:harakiri_server,:clear)

  @doc """
    Server callbacks
  """
  def handle_call({:add, new_ag}, _from, data), do: {:reply, :ok, data ++ [new_ag]}
  def handle_call(:state, _from, data), do: {:reply, data, data}
  def handle_call({:state,data}, _from, _data), do: {:reply, :ok, data}
  def handle_call(:clear, _from, _data), do: {:reply, :ok, []}

  @doc """
    Perform harakiri if given file is touched. Else keep an infinite loop
    sleeping given msecs each time.
  """
  def loop(sleep_ms) do
    for ag <- state, into: [] do

      # check every path
      checked_paths = for p <- ag.paths, into: [] do
        new_mtime = check_file(p,ag)
        [path: p[:path], mtime: new_mtime, hit: p[:mtime] != new_mtime]
      end

      # save new mtimes
      paths = for p <- checked_paths, into: [], do: [path: p[:path], mtime: p[:mtime]]

      # update metadata
      md = ag.metadata
      hit = Enum.reduce(checked_paths, false, fn(p,acc) -> p[:hit] or acc end)
      if hit, do: md = Keyword.put(md, :hits, md[:hits] + 1)
      md = Keyword.put(md, :loops, md[:loops] + 1)

      %{ ag | paths: paths, metadata: md }
    end |> state

    :timer.sleep sleep_ms
    loop sleep_ms
  end

  def check_file(path, ag) do
    new_mtime = get_file_mtime path[:path]
    if path[:mtime] && (path[:mtime] != new_mtime) do
      fire(ag.action, ag.app)
    end
    new_mtime
  end

  def get_file_mtime(path) do
    :os.cmd('ls -l --time-style=full-iso #{path}')
    |> to_string |> String.split |> Enum.at(6)
  end

  def fire(:stop,app) do
    res = Application.stop(app)
    IO.puts "Stopped #{app}... #{inspect res}"
    res = Application.unload app
    IO.puts "Unloaded #{app}... #{inspect res}"
    :ok
  end

  def fire(:restart, app) do
    fire :stop, app
    res = Application.ensure_all_started app
    IO.puts "Started #{app}... #{inspect res}"
    :ok
  end
end
