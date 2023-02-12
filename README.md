# TaggedTopicTrie

A pure-functional trie data structure for matching against topics that can include wildards and tags. It is mainly intended for implementing pub/sub, where clients are regisered on subscription then looked up on publish.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `tagged_topic_trie` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tagged_topic_trie, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/tagged_topic_trie>.

## Usage

A client is registed to the topic "building/floor/room/sensor" as follows:

```elixir
path = "building/floor/room/sensor"
t = 
    TaggedTopicTrie.new()
    |> TaggedTopicTrie.insert(path, "client1")
```

This client can then be fetched using the `find_topic` function to match the exact path.

```elixir
["client1"] = TaggedTopicTrie.find_topic(t, path)
```

The find functions always return a list. If no client is found, the list is empty.

Multiple clients can be registered to the same topic, and multiple inserts of the same client are allowed. Note that clients may be returned in any order.

```elixir
path = "building/floor/room/sensor"
t = 
    TaggedTopicTrie.new() 
    |> TaggedTopicTrie.insert(path, "client1")
    |> TaggedTopicTrie.insert(path, "client1")
    |> TaggedTopicTrie.insert(path, "client2")
    
["client1", "client2"] = TaggedTopicTrie.find_topic(t, path) |> Enum.sort() 
```

Clients can be inserted and retrieved using wilcard topics.  The '*' wildcard will match a single level in the path, unless it is the last level.  In the last position, the wildcard will match all following levels.

```elixir
t = 
    TaggedTopicTrie.new()
    |> TaggedTopicTrie.insert("building/floor1/*/temperature", "client1")
    |> TaggedTopicTrie.insert("building/floor1/room1/*", "client2")

["client1", "client2"] = 
  TaggedTopicTrie.find_wildcard_topic(t, "building/floor1/room1/temperature") |> Enum.sort()

["client2"] = TaggedTopicTrie.find_wildcard_topic(t, "building/floor1/room1/humidity")
```

Topics can be further filtered by tags.  The `find_tagged_topic` function will match if all of the tags inserted with the message are present in the search term.

```elixir
t = 
    TaggedTopicTrie.new()
    |> TaggedTopicTrie.insert("building/floor1/*/temperature", [:group1], "client1")
    |> TaggedTopicTrie.insert("building/floor1/*/temperature", [:group2], "client2")
    |> TaggedTopicTrie.insert("building/floor1/room1/*", [], "client3")

["client1", "client3"] = 
  TaggedTopicTrie.find_tagged_topic(t, "building/floor1/room1/temperature", [:group1])
  |> Enum.sort()
  
["client2", "client3"] = 
  TaggedTopicTrie.find_tagged_topic(t, "building/floor1/room1/temperature", [:group2])
  |> Enum.sort()
```

## Example: Simple Pub/Sub server

```elixir
defmodule SimplePubSub do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, :init, name: __MODULE__)
  end

  def init(:init) do
    {:ok, TaggedTopicTrie.new()}
  end

  def subscribe(topic, tags) do
    GenServer.call(__MODULE__, {:subscribe, topic, tags})
  end

  def unsubscribe(topic, tags) do
    GenServer.call(__MODULE__, {:unsubscribe, topic, tags})
  end

  def publish(topic, tags, message) do
    GenServer.cast(__MODULE__, {:publish, topic, tags, message})
  end

  def handle_call({:subscribe, topic, tags}, {pid, _}, state) do
    state = TaggedTopicTrie.insert(state, topic, tags, pid)
    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, topic, tags}, {pid, _}, state) do
    state = TaggedTopicTrie.remove(state, topic, tags, pid)
    {:reply, :ok, state}
  end

  def handle_cast({:publish, topic, tags, message}, state) do
    clients = TaggedTopicTrie.find_tagged_topic(state, topic, tags)

    Enum.each(
      clients,
      fn pid ->
        send(pid, {:publish, %{topic: topic, tags: tags, message: message}})
      end
    )

    {:noreply, state}
  end
end
```
