defmodule TaggedTopicTrieTest do
  use ExUnit.Case
  doctest TaggedTopicTrie

  test "create a trie" do
    assert TaggedTopicTrie.new() == %TaggedTopicTrie.Node{clients: MapSet.new(), children: %{}}
  end

  test "find a client with basic find" do
    t =
      TaggedTopicTrie.new()
      |> TaggedTopicTrie.insert("level1/level2", "client1")

    assert TaggedTopicTrie.find_topic(t, "level1/level2") == ["client1"]
    assert TaggedTopicTrie.find_topic(t, "level1") == []
  end

  test "find clients with a wildcard topic" do
    t =
      TaggedTopicTrie.new()
      |> TaggedTopicTrie.insert("level1/#", "client1")
      |> TaggedTopicTrie.insert("level1/+/level3/level4", "client2")
      |> TaggedTopicTrie.insert("level1/+/level3", "client3")
      |> TaggedTopicTrie.insert("level1/+", "client4")
      |> TaggedTopicTrie.insert("level1/+/level3/#", "client5")    
      |> TaggedTopicTrie.insert("level1/level2/#/level4", "client6")
    
   assert TaggedTopicTrie.find_wildcard_topic(t, "level1/level2") |> Enum.sort == ["client1", "client4"]

   assert TaggedTopicTrie.find_wildcard_topic(t, "level1/level2/level3") |> Enum.sort() == [
            "client1",
            "client3"
          ]

   assert TaggedTopicTrie.find_wildcard_topic(t, "level1/level2/levelx") |> Enum.sort() == [
            "client1"
   ]

    assert TaggedTopicTrie.find_wildcard_topic(t, "level1/level2") |> Enum.sort() == ["client1", "client4"]
    assert TaggedTopicTrie.find_wildcard_topic(t, "level1/level2/level3/level4") |> Enum.sort() == ["client1", "client2", "client5"]
    assert TaggedTopicTrie.find_wildcard_topic(t, "level1/level2/level3") |> Enum.sort() == ["client1", "client3"]

    assert TaggedTopicTrie.find_wildcard_topic(t, "level1/level2/level3/level4/level5") |> Enum.sort() == ["client1", "client5"]
    assert TaggedTopicTrie.find_wildcard_topic(t, "level1/level2/level3//") |> Enum.sort() == ["client1", "client5"]
    
  end

  test "find clients with a tagged topic" do
    t =
      TaggedTopicTrie.new()
      |> TaggedTopicTrie.insert("level1/level2/#", [:a, :b], "client1")
      |> TaggedTopicTrie.insert("level1/+/level3", [:a, :c], "client2")
      |> TaggedTopicTrie.insert("level1/+/level3", [:a, :c], "client3")
      |> TaggedTopicTrie.insert("level1/level2", [:d, :c], "client4")

    assert TaggedTopicTrie.find_tagged_topic(t, "level1/level2", [:a, :b, :c, :d]) == [
             "client4"
           ]

    assert TaggedTopicTrie.find_tagged_topic(t, "level1/level2", [:a, :b]) == []
    assert TaggedTopicTrie.find_tagged_topic(t, "level1/level2/level3", [:a, :b]) == ["client1"]

    assert TaggedTopicTrie.find_tagged_topic(t, "level1/level2/level3", [:a, :b, :c])
           |> Enum.sort() == ["client1", "client2", "client3"]

    assert TaggedTopicTrie.find_tagged_topic(t, "level1/level2/level3", [:a, :c]) |> Enum.sort() ==
             ["client2", "client3"]
  end

  test "remove client with basic topic" do
    t =
      TaggedTopicTrie.new()
      |> TaggedTopicTrie.insert("level1/level2", "client1")
      |> TaggedTopicTrie.insert("level1/level2", "client2")
      |> TaggedTopicTrie.insert("level1/level2/level3", "client3")

    t1 = TaggedTopicTrie.remove(t, "level1/level2", "client2")
    assert TaggedTopicTrie.find_topic(t1, "level1/level2") == ["client1"]
    assert TaggedTopicTrie.find_topic(t1, "level1/level2/level3") == ["client3"]

    t2 = TaggedTopicTrie.remove(t, "level1/level2/level3", "client3")

    assert TaggedTopicTrie.find_topic(t2, "level1/level2") |> Enum.sort() == [
             "client1",
             "client2"
           ]

    assert TaggedTopicTrie.find_topic(t2, "level1/level2/level3") == []
  end

  test "remove client with wildcard topic" do
    t =
      TaggedTopicTrie.new()
      |> TaggedTopicTrie.insert("level1/#", "client1")
      |> TaggedTopicTrie.insert("level1/level2", "client2")
      |> TaggedTopicTrie.insert("level1/+/level3", "client3")

    assert TaggedTopicTrie.find_wildcard_topic(t, "level1/level2") == ["client1", "client2"]
    
    t1 = TaggedTopicTrie.remove(t, "level1/level2", "client2")
    assert TaggedTopicTrie.find_wildcard_topic(t1, "level1/level2") == ["client1"]
    assert TaggedTopicTrie.find_wildcard_topic(t1, "level1/level2/level3") |> Enum.sort() == ["client1", "client3"]

    t2 = TaggedTopicTrie.remove(t, "level1/+/level3", "client3")
    t2 = TaggedTopicTrie.remove(t2, "level1/level2", "client1")

    assert TaggedTopicTrie.find_wildcard_topic(t2, "level1/level2") |> Enum.sort() == [
             "client1",
             "client2"
           ]

    assert TaggedTopicTrie.find_wildcard_topic(t2, "level1/level2/level3") == ["client1"]
  end

  test "remove client with tagged topic" do
    # Test with clients that vary only by tags
    t =
      TaggedTopicTrie.new()
      |> TaggedTopicTrie.insert("level1/#", [:a], "client1")
      |> TaggedTopicTrie.insert("level1/level2", [:a, :b], "client2")
      |> TaggedTopicTrie.insert("level1/+/level3", [:c], "client3")

    t1 = TaggedTopicTrie.remove(t, "level1/level2", "client2", [:a, :b])
    assert TaggedTopicTrie.find_tagged_topic(t1, "level1/level2", [:a, :b]) == ["client1"]

    assert TaggedTopicTrie.find_tagged_topic(t1, "level1/level2/level3", [:a, :b, :c]) == [
             "client1", "client3"
           ]

    t2 = TaggedTopicTrie.remove(t, "level1/+/level3", "client3", [:c])
    t2 = TaggedTopicTrie.remove(t2, "level1/*", "client1", [:c])

    assert TaggedTopicTrie.find_tagged_topic(t2, "level1/level2", [:a, :b, :c]) |> Enum.sort() ==
             ["client1", "client2"]

    assert TaggedTopicTrie.find_tagged_topic(t2, "level1/level2/level3", [:c]) == []
  end
end
