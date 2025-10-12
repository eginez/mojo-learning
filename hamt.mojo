from collections import List
from memory import UnsafePointer
from testing import assert_equal, assert_true
from bit.bit import pop_count
from logger import Logger, Level
from sys.param_env import env_get_string
from os import env


# Clears the highest 4 bits of the UInt64
# used to truncate the hash
alias FILTER: UInt64 = 0x0FFFFFFFFFFFFFFF
alias logger = Logger()


struct HAMTLeafNode[
    K: Movable & Copyable & Hashable & EqualityComparable, V: Movable & Copyable
](Copyable, Movable):
    var _items: List[Tuple[K, V]]

    fn __init__(out self, key: K, value: V):
        self._items = List[Tuple[K, V]]()
        self.add(key, value)

    fn add(mut self, key: K, value: V):
        for i in range(len(self._items)):
            if self._items[i][0] == key:
                self._items[i] = (key.copy(), value.copy())
                return
        self._items.append(Tuple(key.copy(), value.copy()))

    fn get(self, key: K) -> Optional[V]:
        if len(self._items) == 1:
            if self._items[0][0] == key:
                return Optional(self._items[0][1].copy())

        for item in self._items:
            if item[0] == key:
                return Optional(item[1].copy())
        return Optional[V]()


struct HAMTNode[
    K: Movable & Copyable & Hashable & EqualityComparable, V: Movable & Copyable
](Copyable, Movable):
    # This tells you what children are in this node
    # It represents a sparse array via an intenger
    var children_bitmap: UInt64
    #
    # This gives you the actual child, it is a dense
    # array.
    var children: List[UnsafePointer[HAMTNode[K, V]]]
    var leaf_node: Optional[HAMTLeafNode[K, V]]

    fn __init__(out self):
        self.children_bitmap = 0
        self.children = List[UnsafePointer[HAMTNode[K, V]]]()
        self.leaf_node = Optional[HAMTLeafNode[K, V]]()

    fn add_value(mut self, key: K, value: V):
        if self.leaf_node:
            self.leaf_node.value().add(key, value)
        else:
            self.leaf_node = Optional(HAMTLeafNode(key, value))

    fn get_value(self, key: K) -> Optional[V]:
        if self.leaf_node:
            return self.leaf_node.value().get(key)
        return Optional[V]()

    fn add_child(mut self, chunk_index: UInt8) -> UnsafePointer[HAMTNode[K, V]]:
        masked_chunked = UInt64(1) << UInt64(chunk_index)
        masked_bitmap = UInt64(masked_chunked - 1) & self.children_bitmap
        child_index = pop_count(masked_bitmap)
        self.children_bitmap |= UInt64(masked_chunked)

        var new_node_pointer = UnsafePointer[HAMTNode[K, V]].alloc(1)
        new_node_pointer.init_pointee_move(HAMTNode[K, V]())
        var should_shift = child_index < len(self.children)
        self.children.append(new_node_pointer)
        if should_shift:
            for i in range(len(self.children) - 1, child_index, -1):
                self.children[i] = self.children[i - 1]
        self.children[child_index] = new_node_pointer
        return new_node_pointer

    fn get_child(
        self, chunk_index: UInt8
    ) raises -> UnsafePointer[HAMTNode[K, V]]:
        # The chunk index as an integer represents
        # the position in the sparse representaion of the node
        # of where we should expect to have a value
        masked_chunked = UInt64(1) << UInt64(chunk_index)
        if (self.children_bitmap & UInt64(masked_chunked)) == 0:
            logger.debug(
                "did not find child, returning null for chunk index",
                chunk_index,
                self.children_bitmap,
            )
            return UnsafePointer[HAMTNode[K, V]]()

        # The actual index of the value, is number of 1s before
        # that position.
        masked_bitmap = UInt64(masked_chunked - 1) & self.children_bitmap
        child_index = pop_count(masked_bitmap)
        assert_true(child_index < len(self.children), "bad child index")
        return self.children[child_index]

    fn __del__(deinit self):
        for child in self.children:
            if child:
                child.destroy_pointee()
                child.free()


struct HAMT[
    K: Movable & Copyable & Hashable & EqualityComparable, V: Movable & Copyable
]:
    var root: UnsafePointer[HAMTNode[K, V]]
    var _max_level: UInt16
    var _custom_hash_fn: Optional[fn (K) -> UInt64]

    fn __init__(out self):
        self.root = UnsafePointer[HAMTNode[K, V]].alloc(1)
        self.root.init_pointee_move(HAMTNode[K, V]())
        self._custom_hash_fn = Optional[fn (K) -> UInt64]()
        # TODO make this a comptime var
        self._max_level = 10

    fn __init__(out self, hash_fn: fn (K) -> UInt64):
        self.root = UnsafePointer[HAMTNode[K, V]].alloc(1)
        self.root.init_pointee_move(HAMTNode[K, V]())
        self._custom_hash_fn = Optional(hash_fn)
        self._max_level = 10

    fn get(self, key: K) raises -> Optional[V]:
        if not self.root:
            return None

        var curr_level: UInt16 = 0
        var curr_node = self.root
        var hashed_key = self._calculate_hash(key)

        # The tree only allows for 10 levels, since  we are
        # spliting the hashed keys into chuncks of 6
        # and the hash key is of size 60 bits
        while curr_level < self._max_level:
            chunk_index = self._get_next_chunk(hashed_key, curr_level)
            curr_node = curr_node[].get_child(chunk_index)
            if not curr_node:
                return Optional[V]()
            curr_level += 1

        return curr_node[].get_value(key)

    fn set(mut self, key: K, value: V) raises:
        var curr_level: UInt16 = 0
        var curr_node = self.root
        var hashed_key = self._calculate_hash(key)

        while curr_level < self._max_level:
            chunk_index = self._get_next_chunk(hashed_key, curr_level)
            var next_node = curr_node[].get_child(chunk_index)
            if not next_node:
                # insert node in the parent at index chunk_index
                next_node = curr_node[].add_child(chunk_index)
            curr_node = next_node
            curr_level += 1

        curr_node[].add_value(key, value)

    @always_inline
    fn _get_next_chunk(self, hashed_key: UInt64, level: UInt16) -> UInt8:
        return UInt8((hashed_key >> UInt64(6 * level)) & 0x3F)

    @always_inline
    fn _calculate_hash(self, key: K) -> UInt64:
        """
        This returns an integer of size 60 bits, by clearing the top 4 bits
        """
        var hashed_key: UInt64
        if self._custom_hash_fn:
            hashed_key = self._custom_hash_fn.value()(key)
        else:
            hashed_key = hash(key)

        var filtered_key = hashed_key & FILTER

        # logger.debug("Original " + bin(hashed_key)[2:].rjust(64, "0"))
        # logger.debug("Filtered " + bin(filtered_key)[2:].rjust(64, "0"))

        return filtered_key

    fn __del__(deinit self):
        if self.root:
            self.root.destroy_pointee()
            self.root.free()


fn main() raises:
    var node = HAMT[Int, Int]()
    node.set(1, 1)
    print(node.get(1).or_else(-1))
