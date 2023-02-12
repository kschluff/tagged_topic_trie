defmodule TaggedTopicTrie do
  @moduledoc """
  Inserting wildcard topics and finding without the wilcard might seem backwards,
  but that is because it is intended for pub/sub systems.  That's also why it
  refers to saving clients.
  """
  defmodule Node do
    defstruct clients: MapSet.new(), children: %{}
  end

  def new() do
    %Node{clients: MapSet.new(), children: %{}}
  end

  def find_topic(node, path) when is_binary(path) do
    find_topic(node, String.split(path, "/"))
  end

  def find_topic(node, []) do
    MapSet.to_list(node.clients)
  end

  def find_topic(node, [h | t]) do
    case Map.get(node.children, h) do
      nil -> []
      child -> find_topic(child, t)
    end
  end

  def find_wildcard_topic(node, path) when is_binary(path) do
    do_find_wildcard_topic(node, String.split(path, "/"), [])
  end

  def find_wildcard_topic(node, path) do
    do_find_wildcard_topic(node, path, [])
  end

  defp do_find_wildcard_topic(node, [], found) do
    Enum.concat(found, MapSet.to_list(node.clients))
  end

  defp do_find_wildcard_topic(node, [h | t], found) do
    found =
      case Map.get(node.children, "*") do
        nil -> found
        child -> do_find_wildcard_topic(child, t, found)
      end

    case Map.get(node.children, h) do
      nil -> found
      child -> do_find_wildcard_topic(child, t, found)
    end
  end

  def find_tagged_topic(node, path, tags) when is_binary(path) do
    do_find_tagged_topic(node, String.split(path, "/"), MapSet.new(tags), [])
  end

  def find_tagged_topic(node, path, tags) do
    do_find_tagged_topic(node, path, MapSet.new(tags), [])
  end

  defp do_find_tagged_topic(node, [], tags, found) do
    Enum.reduce(node.clients, found, fn {client, client_tags}, result ->
      if MapSet.subset?(client_tags, tags) do
        [client | result]
      else
        result
      end
    end)
  end

  defp do_find_tagged_topic(node, [h | t], tags, found) do
    found =
      case Map.get(node.children, "*") do
        nil -> found
        child -> do_find_tagged_topic(child, t, tags, found)
      end

    case Map.get(node.children, h) do
      nil -> found
      child -> do_find_tagged_topic(child, t, tags, found)
    end
  end

  def insert(node, path, tags, client) do
    insert(node, path, {client, MapSet.new(tags)})
  end

  def insert(node, path, client) when is_binary(path) do
    insert(node, String.split(path, "/"), client)
  end

  def insert(node, [], client) do
    %Node{node | clients: MapSet.put(node.clients, client)}
  end

  def insert(node, [h | t], client) do
    case Map.get(node.children, h) do
      nil -> %Node{node | children: Map.put(node.children, h, insert(new(), t, client))}
      child -> %Node{node | children: Map.put(node.children, h, insert(child, t, client))}
    end
  end

  def remove(node, path, client, tags) do
    remove(node, path, {client, MapSet.new(tags)})
  end

  def remove(node, path, client) when is_binary(path) do
    remove(node, String.split(path, "/"), client)
  end

  def remove(node, [], client) do
    %Node{node | clients: MapSet.delete(node.clients, client)}
  end

  def remove(node, [h | t], client) do
    case Map.get(node.children, h) do
      nil ->
        node

      child ->
        case remove(child, t, client) do
          %Node{children: children, clients: clients}
          when children == %{} and clients == %MapSet{} ->
            %Node{node | children: Map.delete(node.children, h)}

          new_child ->
            %Node{node | children: Map.put(node.children, h, new_child)}
        end
    end
  end
end
