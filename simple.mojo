from memory import UnsafePointer, OwnedPointer
from random import random_si64

# from builtin.value import CollectionElement


struct Node[T: Movable & Copyable](Copyable, Movable):
    var value: T
    var next: UnsafePointer[Node[T]]

    fn __init__(out self, value: T):
        self.value = value
        self.next = UnsafePointer[Node[T]]()

    fn link(mut self, node: Node[T]):
        self.next = UnsafePointer(to=node)


def main():
    var b = {"hi": 10}
    var n = Node[Int](2)
    var m = Node[Int](3)
    n.link(m)
    print(n.value)
    print(n.next[].value)
    var all_nodes = [Node[Int](i) for i in range(10)]
    for i in all_nodes:
        print(i.value)
    print(b.__str__())
