from collections import List
from memory import UnsafePointer
from testing import assert_equal
from bit.bit import pop_count


# Clears the highest 4 bits of the UInt64
# used to truncate the hash
alias FILTER: UInt64 = 0xfffffffffffffff

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
    var children_bitmap: UInt64
    var children: List[UnsafePointer[HAMTNode[K, V]]]
    var leaf: Optional[UnsafePointer[HAMTLeafNode[K, V]]]

    fn __init__(out self):
        self.children_bitmap = 0
        self.children = List[UnsafePointer[HAMTNode[K, V]]]()
        self.leaf = None

    fn get(self, key: K) -> Optional[V]:
      hashed_key = self._calculate_hash(key)
      
      for curr_level in range(10):
        chunk = self._get_next_chunk(hashed_key, curr_level)
        if not(self.children_bitmap & (1 << chunk)):
          return None

        pointer_array_index = pop_count(chunk)





    fn _get_next_chunk(self, hashed_key: UInt64, level: UInt16) -> UInt8:
      return UInt8((hashed_key >> UInt64(6 * level)) & 0x3F)

    fn _calculate_hash(self, key: K) -> UInt64:
      hashed_key = hash(key)
      return hashed_key & FILTER


fn main() raises:
    node = HAMTNode[Int, Int]()
    assert_equal(node.children_bitmap, 0)
    assert_equal(len(node.children), 0)


# =================================
# Tests
