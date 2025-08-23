from collections import List
from memory import UnsafePointer
from testing import assert_equal
from bit.bit import pop_count
from logger import Logger, Level
from sys.param_env import env_get_string
from os import env


# Clears the highest 4 bits of the UInt64
# used to truncate the hash
alias FILTER: UInt64 = 0x0fffffffffffffff
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
    var children_bitmap: UInt64
    var children: List[UnsafePointer[HAMTNode[K, V]]]
    var leaf: Optional[UnsafePointer[HAMTLeafNode[K, V]]]

    fn __init__(out self):
        self.children_bitmap = 0
        self.children = List[UnsafePointer[HAMTNode[K, V]]]()
        self.leaf = None


    fn get(self, child_index: UInt8) -> Optional[HAMTNode[K,V]]:
      if child_index >= len(self.children):
        return None

    @always_inline
    fn _get_next_chunk(self, hashed_key: UInt64, level: UInt16) -> UInt8:
      return UInt8((hashed_key >> UInt64(6 * level)) & 0x3F)

    @always_inline
    fn _calculate_hash(self, key: K) -> UInt64:
      hashed_key = hash(key)
      filtered_key = hashed_key & FILTER

      logger.debug("Original "+ bin(hashed_key)[2:].rjust(64, '0'))
      logger.debug("Filtered "+ bin(filtered_key)[2:].rjust(64, '0'))

      return filtered_key

struct HAMT[K: Movable & Copyable & Hashable,V : Movable & Copyable]:
  var root: Optional[UnsafePointer[HAMTNode[K,V]]]

  fn __init__(out self):
    pass

  fn get(self, key: K) -> Optional[V]:
    hashed_key = self._calculate_hash(key)
    
    for curr_level in range(10):
      chunk = self._get_next_chunk(hashed_key, curr_level)
      if not(self.children_bitmap & UInt64(1 << chunk)):
        return None

      pointer_array_index = pop_count(chunk)
    return None



fn main() raises:
    node = HAMTNode[Int, Int]()
    assert_equal(node.children_bitmap, 0)
    assert_equal(len(node.children), 0)
    for i in range(10):
      print(len(bin(node._calculate_hash(i))))


# =================================
# Tests
