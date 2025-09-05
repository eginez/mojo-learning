from testing import assert_equal, assert_true, assert_false
from hamt import HAMTLeafNode, HAMTNode, HAMT


def test_hamt_leaf_node():
    var leaf = HAMTLeafNode[String, Int]("test_key", 42)
    assert_equal(leaf.key, "test_key")
    assert_equal(leaf.value, 42)
    print("✓ HAMTLeafNode tests passed")


def test_hamt_node_initialization():
    var node = HAMTNode[String, Int]()
    assert_equal(node.children_bitmap, 0)
    assert_equal(len(node.children), 0)
    print("✓ HAMTNode initialization tests passed")


def test_hamt_hash_calculation():
    var hamt = HAMT[Int, String]()

    # Test that hash calculation returns 60-bit values
    var hash1 = hamt._calculate_hash(42)
    var hash2 = hamt._calculate_hash(100)

    # Verify the top 4 bits are cleared (60-bit hash)
    assert_equal(hash1 >> 60, 0)
    assert_equal(hash2 >> 60, 0)

    # Different keys should produce different hashes (most of the time)
    # This is probabilistic but very likely to pass
    assert_equal(hash1 == hash2, False)
    print("✓ HAMT hash calculation tests passed")


def test_hamt_chunk_extraction():
    var hamt = HAMT[Int, String]()

    # Test chunk extraction at different levels
    # For a 60-bit hash split into 6-bit chunks, we have 10 levels (0-9)
    var test_hash: UInt64 = (
        0b111111000000111111000000111111000000111111000000111111000000
    )

    # Level 0: bits 0-5
    var chunk0 = hamt._get_next_chunk(test_hash, 0)
    assert_equal(chunk0, 0b000000)  # Bottom 6 bits

    # Level 1: bits 6-11
    var chunk1 = hamt._get_next_chunk(test_hash, 1)
    assert_equal(chunk1, 0b111111)

    # Level 2: bits 12-17
    var chunk2 = hamt._get_next_chunk(test_hash, 2)
    assert_equal(chunk2, 0b000000)

    print("✓ HAMT chunk extraction tests passed")


def test_hamt_node_get_child():
    var node = HAMTNode[String, Int]()

    # Test get_child on empty node returns null pointer
    var result = node.get_child(0)
    assert_false(result)

    var result2 = node.get_child(5)
    assert_false(result2)

    # Test bitmap operations manually
    var test_bitmap: UInt64 = 0
    test_bitmap |= UInt64(1) << 5  # Set bit 5
    assert_equal((test_bitmap >> 5) & 1, 1)


def test_hamt_value_creation():
    var node = HAMTNode[String, Int]()
    node.add_value("hello", 1)
    assert_equal(node.get_value("hello").value(), 1)


def test_hamt_creation():
    var node = HAMT[Int, Int]()
    node.set(1, 1)
    # assert_equal(node.get(1).value(), 1)
