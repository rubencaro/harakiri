
defmodule Harakiri.ActionGroup do
  defstruct paths: [],
            app: nil,
            action: nil,
            lib_path: nil,
            metadata: [loops: 0, hits: 0]
end

defmodule Harakiri.Helpers do

  @doc """
    Convenience to get environment bits. Avoid all that repetitive
    `Application.get_env( :myapp, :blah, :blah)` noise.
  """
  def env(key, default \\ nil), do: env(:syscrap, key, default)
  def env(app, key, default), do: Application.get_env(app, key, default)

  @doc """
    Spit to logger any passed variable, with location information.
  """
  defmacro spit(obj, inspect_opts \\ []) do
    quote do
      %{file: file, line: line} = __ENV__
      [ :bright, :red, "\n\n#{file}:#{line}",
        :normal, "\n\n#{inspect(unquote(obj),unquote(inspect_opts))}\n\n", :reset]
      |> IO.ANSI.format(true) |> IO.puts
    end
  end

  @doc """
    Gets a `Map` and puts it into an `ActionGroup` just the way `Harakiri`
    needs it.

    The `Map` should look like:
    ```
    %{paths: ["file1","file2"], app: :myapp, action: :reload, lib_path: "path"}
    ```
  """
  def digest_data(data) when is_map(data) do
    data = %Harakiri.ActionGroup{} |> Map.merge data # put into an ActionGroup
    paths = for p <- data.paths, into: [] do
      [path: p, mtime: Harakiri.Worker.get_file_mtime(p)]
    end
    %{data | paths: paths}
  end

  @doc """
    Generate de md5 hash to be used as key for the ETS table
  """
  def md5_key(data) do
    # whatever it is, make it hashable
    hdata = data |> inspect |> to_char_list
    :crypto.hash :md5, hdata
  end

  @doc """
    Insert given data to `:harakiri_table`
  """
  def insert(data) when is_map(data) do
    :ets.insert(:harakiri_table, {md5_key(data), data})
  end

end
