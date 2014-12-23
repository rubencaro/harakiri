# Harakiri

Given a list of _files_, an _application_, and an _action_. When any of the
files change on disk (i.e. a gentle `touch` is enough), then the given action
is fired over the app. `Harakiri` was concieved to help applications kill
themselves in response to a `touch` to a file on disk. Hence the name.

Everything is in an OTP Application so you can have it running in your
system to help all your other applications kill themselves.

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
    Harakiri.Worker.add %{paths: ["file1","file2"], app: :myapp, action: :restart}
```

You are done. All given files (`file1`, `file2`, etc.) must exist.

## Demo

http://asciinema.org/a/14617

## TODOs

* Allow only one instance of the same action group.
* Get it stable on production
* Add to hex
* Add to travis
* Use ETS to preserve state
* Optional creation of watched files.
* Support for multiple apps on each action set.
* Support for several actions on each action set.
* Support for multiple action sets on the same Harakiri process.
* More actions, or even support for funs.
