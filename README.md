# Harakiri

Given a list of _files_, an _application_, and an _action_. When any of the
files change on disk (i.e. a gentle `touch` is enough), then the given action
is fired over the app. `Harakiri` was concieved to help applications kill
themselves in response to a `touch` to a file on disk. Hence the name.

Everything is in a supervisable `GenServer` so you can easily add it to your
supervision tree.

Actions can be:

* `:stop`: `Application.stop/1` and `Application.unload/1` are called.
* `:restart`: like `:stop` and then `Application.ensure_all_started/1`.

## Use

Add to your `aplications` list to ensure it's up before your app starts.

Add to your `deps` like this:

```elixir
    {:harakiri, github: "elpulgardelpanda/harakiri"}
```

Add an _action group_ like this:

```elixir
    Harakiri.add paths: ["file1","file2"], app: :myapp, action: :restart
```

All given files (`file1`, `file2`, etc.) must exist.

## Demo

https://asciinema.org/a/14560

## TODOs

* Get it stable on production
* Add to hex
* Add to travis
* Use ETS to preserve state
* Optional creation of watched files.
* Support for multiple apps on each action set.
* Support for several actions on each action set.
* Support for multiple action sets on the same Harakiri process.
* More actions, or even support for funs.
