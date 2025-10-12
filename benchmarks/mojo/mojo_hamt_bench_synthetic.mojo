"""
Synthetic Dataset Benchmarks for HAMT Implementation

This benchmark suite implements section 6.1.1 (Synthetic Datasets) from the README.
It tests controlled performance characteristics using programmatically generated data:

1. Sequential integers: Keys 0, 1, 2, ..., N
   - Tests best-case insertion and lookup performance
   - Tests HAMT behavior with predictable, non-colliding hash patterns
   - Sizes: 100, 1K, 10K, 100K, 1M entries

2. Random integers: Uniformly distributed random Int64 values
   - Tests average-case performance with realistic hash distribution
   - Simulates real-world integer keys (IDs, timestamps, etc.)
   - Sizes: 100, 1K, 10K, 100K, 1M entries

3. Collision-prone keys: Keys with custom hash forcing collisions
   - Tests worst-case performance when many keys hash to same path
   - Tests leaf node collision handling and tree depth under stress
   - Uses custom hash: hash(key) % 1000 to force collisions
   - Sizes: 1K, 10K, 100K entries

Metrics tracked per benchmark:
- Throughput (operations per second)
- Latency (mean nanoseconds per operation)
- Total time (nanoseconds)
- Memory characteristics (manual inspection)

Output:
- CSV file saved to: benchmarks/data/synthetic_benchmarks.csv
- Format: method,dataset_type,operation,size,total_time_ns,ops_per_sec,ns_per_op
- Method column allows comparison between implementations (mojo-hamt, python-dict, libhamt, etc.)
"""

from time import perf_counter_ns
from random import random_si64
from collections import List
from memory import UnsafePointer
from testing import assert_equal, assert_true
from os import abort


# Import HAMT from the source directory
from hamt import HAMT


struct BenchmarkResult(Stringable, Copyable, Movable):
    """Stores the results of a single benchmark run."""
    var name: String
    var method: String
    var dataset_type: String
    var operation: String
    var size: Int
    var total_time_ns: Int
    var ops_per_sec: Float64
    var ns_per_op: Float64

    fn __init__(
        out self,
        name: String,
        method: String,
        dataset_type: String,
        operation: String,
        size: Int,
        total_time_ns: Int
    ):
        self.name = name
        self.method = method
        self.dataset_type = dataset_type
        self.operation = operation
        self.size = size
        self.total_time_ns = total_time_ns
        self.ops_per_sec = Float64(size) / (Float64(total_time_ns) / 1_000_000_000.0)
        self.ns_per_op = Float64(total_time_ns) / Float64(size)

    fn __str__(self) -> String:
        var result = String("")
        result += "Method: " + self.method + "\n"
        result += "Dataset: " + self.dataset_type + "\n"
        result += "Operation: " + self.operation + "\n"
        result += "Size: " + String(self.size) + " entries\n"
        result += "Total time: " + String(self.total_time_ns) + " ns\n"
        result += "Throughput: " + String(Int(self.ops_per_sec)) + " ops/sec\n"
        result += "Latency: " + String(Int(self.ns_per_op)) + " ns/op\n"
        return result

    fn print_table_row(self):
        """Print as a table row for summary output."""
        print(
            self.method.ljust(15),
            self.dataset_type.ljust(20),
            self.operation.ljust(15),
            String(self.size).rjust(10),
            String(Int(self.ops_per_sec)).rjust(15),
            String(Int(self.ns_per_op)).rjust(12)
        )

    fn to_csv_row(self) -> String:
        """Convert result to CSV row format."""
        var row = String("")
        row += self.method + ","
        row += self.dataset_type + ","
        row += self.operation + ","
        row += String(self.size) + ","
        row += String(self.total_time_ns) + ","
        row += String(self.ops_per_sec) + ","
        row += String(self.ns_per_op)
        return row


# ============================================================================
# 1. SEQUENTIAL INTEGER BENCHMARKS
# ============================================================================

fn bench_sequential_insert(size: Int) raises -> BenchmarkResult:
    """Benchmark: Insert sequential integer keys 0, 1, 2, ..., N-1.

    What it tests: Best-case insertion performance with predictable hashing.
    """
    var hamt = HAMT[Int, Int]()

    var start = perf_counter_ns()
    for i in range(size):
        try:
            hamt[i] = i * 10
        except:
            print("ERROR: Failed to insert key", i)
            abort()
    var end = perf_counter_ns()

    # Verify size
    assert_equal(len(hamt), size, "HAMT size mismatch after sequential insert")

    return BenchmarkResult(
        "Sequential Insert",
        "mojo-hamt",
        "Sequential Integers",
        "Insert",
        size,
        Int(end - start)
    )


fn bench_sequential_lookup_hits(size: Int) raises -> BenchmarkResult:
    """Benchmark: Lookup all existing sequential keys (100% hit ratio).

    What it tests: Best-case lookup performance for existing keys.
    """
    var hamt = HAMT[Int, Int]()

    # Pre-populate
    for i in range(size):
        try:
            hamt[i] = i * 10
        except:
            print("ERROR: Failed to populate for lookup benchmark")
            abort()

    # Benchmark lookups
    var start = perf_counter_ns()
    for i in range(size):
        try:
            var value = hamt[i]
            assert_equal(value, i * 10, "Value mismatch in lookup")
        except:
            print("ERROR: Failed to lookup key", i)
            abort()
    var end = perf_counter_ns()

    return BenchmarkResult(
        "Sequential Lookup (Hits)",
        "mojo-hamt",
        "Sequential Integers",
        "Lookup (Hits)",
        size,
        Int(end - start)
    )


fn bench_sequential_lookup_misses(size: Int) raises -> BenchmarkResult:
    """Benchmark: Lookup non-existent keys (100% miss ratio).

    What it tests: Lookup performance when keys don't exist.
    Inserts even numbers, looks up odd numbers.
    """
    var hamt = HAMT[Int, Int]()

    # Pre-populate with even numbers only
    for i in range(size):
        try:
            hamt[i * 2] = i * 10
        except:
            print("ERROR: Failed to populate for miss benchmark")
            abort()

    # Benchmark lookups of odd numbers (guaranteed misses)
    var start = perf_counter_ns()
    for i in range(size):
        try:
            var result = hamt.get(i * 2 + 1)
            assert_true(not result, "Expected miss, but found value")
        except:
            print("ERROR: Failed in miss benchmark")
            abort()
    var end = perf_counter_ns()

    return BenchmarkResult(
        "Sequential Lookup (Misses)",
        "mojo-hamt",
        "Sequential Integers",
        "Lookup (Misses)",
        size,
        Int(end - start)
    )


fn bench_sequential_update(size: Int) raises -> BenchmarkResult:
    """Benchmark: Update all existing sequential keys.

    What it tests: Performance of updating existing keys (no new allocations).
    """
    var hamt = HAMT[Int, Int]()

    # Pre-populate
    for i in range(size):
        try:
            hamt[i] = i * 10
        except:
            print("ERROR: Failed to populate for update benchmark")
            abort()

    var initial_size = len(hamt)

    # Benchmark updates
    var start = perf_counter_ns()
    for i in range(size):
        try:
            hamt[i] = i * 20  # Update with new value
        except:
            print("ERROR: Failed to update key", i)
            abort()
    var end = perf_counter_ns()

    # Verify size didn't change
    assert_equal(len(hamt), initial_size, "Size changed during update")

    return BenchmarkResult(
        "Sequential Update",
        "mojo-hamt",
        "Sequential Integers",
        "Update",
        size,
        Int(end - start)
    )


fn bench_sequential_contains(size: Int) raises -> BenchmarkResult:
    """Benchmark: Contains check for all sequential keys.

    What it tests: Performance of membership testing (__contains__).
    """
    var hamt = HAMT[Int, Int]()

    # Pre-populate
    for i in range(size):
        try:
            hamt[i] = i * 10
        except:
            print("ERROR: Failed to populate for contains benchmark")
            abort()

    # Benchmark contains checks
    var start = perf_counter_ns()
    for i in range(size):
        try:
            var found = hamt.__contains__(i)
            assert_true(found, "Key should exist")
        except:
            print("ERROR: Failed contains check for key", i)
            abort()
    var end = perf_counter_ns()

    return BenchmarkResult(
        "Sequential Contains",
        "mojo-hamt",
        "Sequential Integers",
        "Contains",
        size,
        Int(end - start)
    )


# ============================================================================
# 2. RANDOM INTEGER BENCHMARKS
# ============================================================================

fn bench_random_insert(size: Int, seed: Int = 42) raises -> BenchmarkResult:
    """Benchmark: Insert random integer keys.

    What it tests: Average-case insertion with realistic hash distribution.
    """
    var hamt = HAMT[Int, Int]()

    # Generate random keys
    var keys = List[Int](capacity=size)
    for _ in range(size):
        keys.append(Int(random_si64(0, Int64.MAX)))

    # Benchmark insertions
    var start = perf_counter_ns()
    for i in range(size):
        try:
            hamt[keys[i]] = i
        except:
            print("ERROR: Failed to insert random key at index", i)
            abort()
    var end = perf_counter_ns()

    # Note: Size may be less than input size due to duplicate random keys
    # This is expected behavior

    return BenchmarkResult(
        "Random Insert",
        "mojo-hamt",
        "Random Integers",
        "Insert",
        size,
        Int(end - start)
    )


fn bench_random_lookup_hits(size: Int, seed: Int = 42) raises -> BenchmarkResult:
    """Benchmark: Lookup random keys that exist (100% hit ratio).

    What it tests: Average-case lookup performance with random access pattern.
    """
    var hamt = HAMT[Int, Int]()

    # Generate and insert random keys
    var keys = List[Int](capacity=size)
    for i in range(size):
        var key = Int(random_si64(0, Int64.MAX))
        keys.append(key)
        try:
            hamt[key] = i
        except:
            print("ERROR: Failed to populate for random lookup benchmark")
            abort()

    # Benchmark lookups
    var start = perf_counter_ns()
    for i in range(size):
        try:
            _ = hamt[keys[i]]
        except:
            print("ERROR: Failed to lookup random key at index", i)
            abort()
    var end = perf_counter_ns()

    return BenchmarkResult(
        "Random Lookup (Hits)",
        "mojo-hamt",
        "Random Integers",
        "Lookup (Hits)",
        size,
        Int(end - start)
    )


fn bench_random_lookup_misses(size: Int, seed: Int = 42) raises -> BenchmarkResult:
    """Benchmark: Lookup random keys that don't exist (100% miss ratio).

    What it tests: Miss performance with random access pattern.
    Inserts with seed=42, looks up with seed=99 (different keys).
    """
    var hamt = HAMT[Int, Int]()

    # Populate with one set
    for i in range(size):
        var key = Int(random_si64(0, Int64.MAX))
        try:
            hamt[key] = i
        except:
            print("ERROR: Failed to populate for random miss benchmark")
            abort()

    # Generate different keys for lookups (likely different from populated keys)
    var miss_keys = List[Int](capacity=size)
    for _ in range(size):
        miss_keys.append(Int(random_si64(0, Int64.MAX)))

    # Benchmark lookups (mostly misses, some rare hits by chance)
    var start = perf_counter_ns()
    for i in range(size):
        try:
            _ = hamt.get(miss_keys[i])
        except:
            print("ERROR: Failed in random miss benchmark")
            abort()
    var end = perf_counter_ns()

    return BenchmarkResult(
        "Random Lookup (Misses)",
        "mojo-hamt",
        "Random Integers",
        "Lookup (Misses)",
        size,
        Int(end - start)
    )


fn bench_random_update(size: Int, seed: Int = 42) raises -> BenchmarkResult:
    """Benchmark: Update random keys that exist.

    What it tests: Update performance with random access pattern.
    """
    var hamt = HAMT[Int, Int]()

    # Generate and insert random keys
    var keys = List[Int](capacity=size)
    for i in range(size):
        var key = Int(random_si64(0, Int64.MAX))
        keys.append(key)
        try:
            hamt[key] = i
        except:
            print("ERROR: Failed to populate for random update benchmark")
            abort()

    var initial_size = len(hamt)

    # Benchmark updates
    var start = perf_counter_ns()
    for i in range(size):
        try:
            hamt[keys[i]] = i * 2  # Update with new value
        except:
            print("ERROR: Failed to update random key at index", i)
            abort()
    var end = perf_counter_ns()

    # Size should remain the same
    assert_equal(len(hamt), initial_size, "Size changed during random update")

    return BenchmarkResult(
        "Random Update",
        "mojo-hamt",
        "Random Integers",
        "Update",
        size,
        Int(end - start)
    )


# ============================================================================
# 3. COLLISION-PRONE KEY BENCHMARKS
# ============================================================================

fn collision_hash(key: Int) -> UInt64:
    """Custom hash function that forces collisions.

    Maps all keys to hash space of only 1000 values.
    This tests leaf node collision handling.
    """
    return UInt64(key % 1000)


fn bench_collision_insert(size: Int) raises -> BenchmarkResult:
    """Benchmark: Insert keys with collision-prone hash function.

    What it tests: Worst-case insertion when many keys hash to same path.
    Tests leaf node collision handling and tree depth under stress.
    Expected behavior: Multiple key-value pairs in same leaf nodes.
    """
    var hamt = HAMT[Int, Int](collision_hash)

    var start = perf_counter_ns()
    for i in range(size):
        try:
            hamt[i] = i * 10
        except:
            print("ERROR: Failed to insert collision-prone key", i)
            abort()
    var end = perf_counter_ns()

    # Verify all keys were inserted
    assert_equal(len(hamt), size, "HAMT size mismatch after collision insert")

    return BenchmarkResult(
        "Collision-Prone Insert",
        "mojo-hamt",
        "Collision-Prone",
        "Insert",
        size,
        Int(end - start)
    )


fn bench_collision_lookup_hits(size: Int) raises -> BenchmarkResult:
    """Benchmark: Lookup keys with collision-prone hash (hits).

    What it tests: Lookup performance when multiple keys share hash prefixes.
    Requires linear scan within leaf nodes.
    """
    var hamt = HAMT[Int, Int](collision_hash)

    # Pre-populate
    for i in range(size):
        try:
            hamt[i] = i * 10
        except:
            print("ERROR: Failed to populate for collision lookup benchmark")
            abort()

    # Benchmark lookups
    var start = perf_counter_ns()
    for i in range(size):
        try:
            var value = hamt[i]
            assert_equal(value, i * 10, "Value mismatch in collision lookup")
        except:
            print("ERROR: Failed to lookup collision-prone key", i)
            abort()
    var end = perf_counter_ns()

    return BenchmarkResult(
        "Collision-Prone Lookup (Hits)",
        "mojo-hamt",
        "Collision-Prone",
        "Lookup (Hits)",
        size,
        Int(end - start)
    )


fn bench_collision_update(size: Int) raises -> BenchmarkResult:
    """Benchmark: Update keys with collision-prone hash.

    What it tests: Update performance with high collision rate.
    """
    var hamt = HAMT[Int, Int](collision_hash)

    # Pre-populate
    for i in range(size):
        try:
            hamt[i] = i * 10
        except:
            print("ERROR: Failed to populate for collision update benchmark")
            abort()

    var initial_size = len(hamt)

    # Benchmark updates
    var start = perf_counter_ns()
    for i in range(size):
        try:
            hamt[i] = i * 20  # Update with new value
        except:
            print("ERROR: Failed to update collision-prone key", i)
            abort()
    var end = perf_counter_ns()

    # Verify size didn't change
    assert_equal(len(hamt), initial_size, "Size changed during collision update")

    return BenchmarkResult(
        "Collision-Prone Update",
        "mojo-hamt",
        "Collision-Prone",
        "Update",
        size,
        Int(end - start)
    )


# ============================================================================
# MAIN BENCHMARK RUNNER
# ============================================================================

fn print_header():
    """Print the benchmark suite header."""
    print("\n" + "═" * 80)
    print("  HAMT SYNTHETIC DATASET BENCHMARKS (Section 6.1.1)")
    print("═" * 80)
    print("\nDataset Types:")
    print("  1. Sequential Integers: 0, 1, 2, ..., N (predictable hashing)")
    print("  2. Random Integers: Uniform random Int64 (realistic distribution)")
    print("  3. Collision-Prone: Custom hash forcing collisions (stress test)")
    print("\nSizes: 100, 1K, 10K, 100K, 1M entries")
    print("=" * 80 + "\n")


fn print_table_header():
    """Print the summary table header."""
    print("\n" + "─" * 90)
    print("BENCHMARK SUMMARY TABLE")
    print("─" * 90)
    print(
        "Method".ljust(15),
        "Dataset".ljust(20),
        "Operation".ljust(15),
        "Size".rjust(10),
        "Throughput".rjust(15),
        "Latency".rjust(12)
    )
    print(
        "".ljust(15),
        "".ljust(20),
        "".ljust(15),
        "".rjust(10),
        "(ops/sec)".rjust(15),
        "(ns/op)".rjust(12)
    )
    print("─" * 90)


fn print_section(title: String):
    """Print a section header."""
    print("\n" + "─" * 80)
    print(title)
    print("─" * 80 + "\n")


fn save_results_to_csv(results: List[BenchmarkResult], filepath: String) raises:
    """Save benchmark results to a CSV file.

    Args:
        results: List of benchmark results to save.
        filepath: Path to the output CSV file.
    """
    var csv_content = String("method,dataset_type,operation,size,total_time_ns,ops_per_sec,ns_per_op\n")

    for i in range(len(results)):
        csv_content += results[i].to_csv_row() + "\n"

    # Write to file
    with open(filepath, "w") as f:
        f.write(csv_content)

    print("\n✓ Results saved to:", filepath)


fn main() raises:
    print_header()

    # Benchmark sizes as specified in README
    var sizes = List[Int](100, 1_000, 10_000, 100_000, 1_000_000)

    # Store all results for summary table
    var results = List[BenchmarkResult]()

    # ========================================================================
    # 1. SEQUENTIAL INTEGER BENCHMARKS
    # ========================================================================

    print_section("1. SEQUENTIAL INTEGER BENCHMARKS")
    print("Testing best-case performance with predictable, non-colliding hashes\n")

    for size_idx in range(len(sizes)):
        var size = sizes[size_idx]
        print("  Running sequential benchmarks for size:", size)

        var r = bench_sequential_insert(size)
        results.append(r^)

        r = bench_sequential_lookup_hits(size)
        results.append(r^)

        r = bench_sequential_lookup_misses(size)
        results.append(r^)

        r = bench_sequential_update(size)
        results.append(r^)

        r = bench_sequential_contains(size)
        results.append(r^)

        print("  ✓ Completed sequential benchmarks for size:", size, "\n")

    # ========================================================================
    # 2. RANDOM INTEGER BENCHMARKS
    # ========================================================================

    print_section("2. RANDOM INTEGER BENCHMARKS")
    print("Testing average-case performance with realistic hash distribution\n")

    for size_idx in range(len(sizes)):
        var size = sizes[size_idx]
        print("  Running random benchmarks for size:", size)

        var r = bench_random_insert(size)
        results.append(r^)

        r = bench_random_lookup_hits(size)
        results.append(r^)

        r = bench_random_lookup_misses(size)
        results.append(r^)

        r = bench_random_update(size)
        results.append(r^)

        print("  ✓ Completed random benchmarks for size:", size, "\n")

    # ========================================================================
    # 3. COLLISION-PRONE KEY BENCHMARKS
    # ========================================================================

    print_section("3. COLLISION-PRONE KEY BENCHMARKS")
    print("Testing worst-case performance with forced hash collisions")
    print("Custom hash: hash(key) % 1000 (reduces hash space to 1000 values)\n")

    # Collision benchmarks use smaller sizes as specified in README
    var collision_sizes = List[Int](1_000, 10_000, 100_000)

    for size_idx in range(len(collision_sizes)):
        var size = collision_sizes[size_idx]
        print("  Running collision benchmarks for size:", size)

        var r = bench_collision_insert(size)
        results.append(r^)

        r = bench_collision_lookup_hits(size)
        results.append(r^)

        r = bench_collision_update(size)
        results.append(r^)

        print("  ✓ Completed collision benchmarks for size:", size, "\n")

    # ========================================================================
    # SUMMARY TABLE
    # ========================================================================

    print_table_header()
    for result_idx in range(len(results)):
        results[result_idx].print_table_row()
    print("─" * 80)

    # ========================================================================
    # SAVE RESULTS TO CSV
    # ========================================================================

    save_results_to_csv(results, "benchmarks/data/synthetic_benchmarks.csv")

    print("\n" + "═" * 80)
    print("  BENCHMARK SUITE COMPLETED SUCCESSFULLY")
    print("  Total benchmarks run:", len(results))
    print("═" * 80 + "\n")
