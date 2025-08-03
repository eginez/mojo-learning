from collections import LinkedList
from memory import UnsafePointer
from testing import assert_equal


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
    var children: LinkedList[UnsafePointer[HAMTNode[K, V]]]
    var leaf: Optional[UnsafePointer[HAMTLeafNode[K, V]]]

    fn __init__(out self):
        self.children_bitmap = 0
        self.children = LinkedList[UnsafePointer[HAMTNode[K, V]]]()
        self.leaf = None


fn main() raises:
    node = HAMTNode[Int, Int]()
    assert_equal(node.children_bitmap, 0)
    assert_equal(len(node.children), 0)


# =================================
# Tests
