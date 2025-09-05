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


struct HAMTLeafNode[K: Movable & Copyable & Hashable, V: Movable & Copyable](
    Copyable, Movable
):
    var key: K
    var value: V

    fn __init__(out self, key: K, value: V):
        self.key = key
        self.value = value


struct HAMTNode[K: Movable & Copyable & Hashable, V: Movable & Copyable](
    Copyable, Movable
):
    # This tells you what children are in this node
    # It represents a sparse array via an intenger
    var children_bitmap: UInt64
    #
    # This tells gives you the actual child, it is a dense
    # array.
    var children: List[UnsafePointer[HAMTNode[K, V]]]
    var leaf_node: Optional[HAMTLeafNode[K, V]]

    fn __init__(out self):
        self.children_bitmap = 0
        self.children = List[UnsafePointer[HAMTNode[K, V]]]()
        self.leaf_node = Optional[HAMTLeafNode[K, V]]()

    fn add_value(mut self, key: K, value: V):
        self.leaf_node = Optional(HAMTLeafNode(key, value))

    fn get_value(self, key: K) raises -> Optional[V]:
        assert_true(self.leaf_node, "Node needs to have value")
        if hash(key) == hash(self.leaf_node.value().key):
            return Optional(self.leaf_node.value().value)
        return Optional[V]()

    fn add_child(mut self, chunk_index: UInt8) -> UnsafePointer[HAMTNode[K, V]]:
        masked_chunked = UInt8(1) << chunk_index
        self.children_bitmap |= UInt64(masked_chunked)
        masked_bitmap = UInt64(masked_chunked - 1) & self.children_bitmap
        child_index = pop_count(masked_bitmap)
        #
        # I might have to add an element to the list
        var new_node_pointer = UnsafePointer(to=HAMTNode[K, V]())
        if child_index > len(self.children):
            self.children.append(new_node_pointer)
        else:
            self.children[child_index] = new_node_pointer
        return new_node_pointer

    fn get_child(self, chunk_index: UInt8) -> UnsafePointer[HAMTNode[K, V]]:
        # The chunk index as an integer represents
        # the position in the sparse representaion of the node
        # of where we should expedt to have a value
        masked_chunked = UInt8(1) << chunk_index
        if not (self.children_bitmap & UInt64(masked_chunked)):
            var new_node_pointer = UnsafePointer[HAMTNode[K, V]].alloc(1)
            # new_node_pointer.init_pointee_move(HAMTNode[K, V]())
            return new_node_pointer

        # The actual index of the value, is number of 1s before
        # that position.
        masked_bitmap = UInt64(masked_chunked - 1) & self.children_bitmap
        child_index = pop_count(masked_bitmap)
        return self.children[child_index]


struct HAMT[K: Movable & Copyable & Hashable, V: Movable & Copyable]:
    var root: UnsafePointer[HAMTNode[K, V]]
    var _max_level: UInt16

    fn __init__(out self):
        self.root = UnsafePointer(to=HAMTNode[K, V]())
        self._max_level = 10
        pass

    fn get(self, key: K) raises -> Optional[V]:
        if self.root:
            return None

        var curr_level: UInt16 = 0
        var curr_node = self.root

        # The tree only allows for 10 levels, since  we are
        # spliting the hashed keys into chuncks of 6
        # and the hash key is of size 60 bits
        # TODO make this a comptime var
        while curr_level < self._max_level:
            hashed_key = self._calculate_hash(key)
            chunk_index = self._get_next_chunk(hashed_key, curr_level)
            curr_node = curr_node[].get_child(chunk_index)
            curr_level += 1

        return curr_node[].get_value(key)

    fn set(self, key: K, value: V):
        var curr_level: UInt16 = 0
        var curr_node = self.root
        print("adding child")

        while curr_level < self._max_level:
            hashed_key = self._calculate_hash(key)
            chunk_index = self._get_next_chunk(hashed_key, curr_level)
            var parent_node = curr_node
            curr_node = curr_node[].get_child(chunk_index)
            if not curr_node:
                # insert node in the parent at index chun_index
                curr_node = parent_node[].add_child(chunk_index)
            curr_level += 1
            print("level", curr_level)

        curr_node[].add_value(key, value)

    @always_inline
    fn _get_next_chunk(self, hashed_key: UInt64, level: UInt16) -> UInt8:
        return UInt8((hashed_key >> UInt64(6 * level)) & 0x3F)

    @always_inline
    fn _calculate_hash(self, key: K) -> UInt64:
        """
        This returns an integer of size 60 bits, by clearing the top 4 bits
        """
        hashed_key = hash(key)
        filtered_key = hashed_key & FILTER

        logger.debug("Original " + bin(hashed_key)[2:].rjust(64, "0"))
        logger.debug("Filtered " + bin(filtered_key)[2:].rjust(64, "0"))

        return filtered_key


fn main() raises:
    var node = HAMT[Int, Int]()
    node.set(1, 1)
    print(node.get(1).or_else(2))
