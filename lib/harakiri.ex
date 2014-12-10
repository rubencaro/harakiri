require Logger

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
  defstruct paths: [], app: nil, action: nil
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
    spawn_link fn -> loop end
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
      [path: p, mtime: File.stat!(p).mtime]
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
  def loop(sleep_ms \\ 5_000) do
    for ag <- state, into: [] do
      Logger.debug inspect(ag)
      paths = for p <- ag.paths, into: [] do
        [path: p[:path], mtime: check_file(p,ag)]
      end
      Logger.debug inspect(paths)
      %{ ag | paths: paths }
    end |> state
    :timer.sleep sleep_ms
    loop sleep_ms
  end

  def check_file(path, %ActionGroup{action: action, app: app}) do
    new_mtime = File.stat!(path[:path]).mtime
    if path[:mtime] && (path[:mtime] != new_mtime), do: fire(action, app)
    new_mtime
  end

  def fire(:stop,app) do
    res = Application.stop(app)
    Logger.info "Stopped #{app}... #{inspect res}"
    res = Application.unload app
    Logger.info "Unloaded #{app}... #{inspect res}"
    :ok
  end

  def fire(:restart, app) do
    fire :stop, app
    res = Application.ensure_all_started app
    Logger.info "Started #{app}... #{inspect res}"
    :ok
  end
end
