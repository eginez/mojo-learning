from collections import List
from memory import UnsafePointer
from testing import assert_equal
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

    fn __init__(out self):
        self.children_bitmap = 0
        self.children = List[UnsafePointer[HAMTNode[K, V]]]()
        self.leaf = None

    fn get_child(self, chunk_index: UInt8) -> Optional[HAMTNode[K, V]]:
        # The chunk index as an integer represents
        # the position in the sparse representaion of the node
        # of where we should expedt to have a value
        masked_chunked = UInt64(1) << chunk_index
        if not (self.children_bitmap & masked_chunked):
            return None

        # The actual index of the value, is number of 1s before
        # that position.
        masked_bitmap = (masked_chunked - 1) & self.children_bitmap
        child_index = pop_count(masked_bitmap)
        return self.children[child_index]


struct HAMT[K: Movable & Copyable & Hashable, V: Movable & Copyable]:
    var root: Optional[UnsafePointer[HAMTNode[K, V]]]

    fn __init__(out self):
        self.root = None
        pass

    fn get(self, key: K) -> Optional[V]:
        if self.root == None:
            return None

        var curr_level = 0
        var curr_node = self.root

        # The tree only allows for 10 levels, since  we are
        # spliting the hashed keys into chuncks of 6
        # and the hash key is of size 60 bits
        while curr_level < 10:
            hashed_key = self._calculate_hash(key)
            chunk_index = self._get_next_chunk(hashed_key, curr_level)
            curr_node = curr_node.get_child(chunk_index)
            if not curr_node:
                return None
            curr_level += 1

        return None

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
    node = HAMTNode[Int, Int]()
    assert_equal(node.children_bitmap, 0)
    assert_equal(len(node.children), 0)
    for i in range(10):
        print(len(bin(node._calculate_hash(i))))


# =================================
# Tests
