"""
Number Benchmarks for HAMT Implementation

This benchmark suite matches the format used by hamt-bench:
https://github.com/mkirchner/hamt-bench

Format matches the 'numbers' table schema:
- product: Implementation name (e.g., "mojo-hamt")
- gitcommit: Git commit hash
- epoch: Unix timestamp
- benchmark: UUID for this benchmark session
- repeat: Repetition number (0-9)
- measurement: Operation type (insert, query, remove)
- scale: Number of entries (1000, 10000, 100000, 1000000)
- ns: Nanoseconds per operation

Operations:
- insert: Insert N sequential integer keys
- query: Lookup existing keys (100% hit ratio)
- remove: Remove keys (not yet implemented in HAMT)

Output:
- CSV file: benchmarks/data/mojo_hamt_numbers.csv
- Format: product,gitcommit,epoch,benchmark,repeat,measurement,scale,ns
"""

from time import perf_counter_ns
from random import seed
from collections import List
from testing import assert_equal
from os import abort
from python import Python
from sys import argv
from utils.index import Index

from hamt import HAMT


# ============================================================================
# CONFIGURATION
# ============================================================================

alias NUM_REPEATS = 10  # Number of times to repeat each benchmark
alias PRODUCT_NAME = "mojo-hamt"


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

fn generate_uuid() raises -> String:
    """Generate a UUID for this benchmark session using Python's uuid library."""
    var py_uuid = Python.import_module("uuid")
    var uuid_obj = py_uuid.uuid4()
    return String(uuid_obj)


fn get_gitcommit() raises -> String:
    """Get the current git commit hash."""
    var subprocess = Python.import_module("subprocess")
    try:
        var result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True,
            text=True,
            check=True
        )
        # Convert PythonObject to String and strip whitespace
        var commit = String()
        result.stdout().write_to(commit)
        return commit
    except:
        return ""


fn get_epoch() raises -> Int:
    """Get current Unix timestamp in seconds."""
    var py_time = Python.import_module("time")
    return Int(py_time.time())


# ============================================================================
# BENCHMARK RESULT STORAGE
# ============================================================================

struct BenchmarkResult(Copyable, Movable):
    """Stores a single benchmark measurement matching hamt-bench format."""
    var product: String
    var gitcommit: String
    var epoch: Int
    var benchmark_uuid: String
    var repeat: Int
    var measurement: String
    var scale: Int
    var ns: Float64

    fn __init__(
        out self,
        product: String,
        gitcommit: String,
        epoch: Int,
        benchmark_uuid: String,
        repeat: Int,
        measurement: String,
        scale: Int,
        ns: Float64
    ):
        self.product = product
        self.gitcommit = gitcommit
        self.epoch = epoch
        self.benchmark_uuid = benchmark_uuid
        self.repeat = repeat
        self.measurement = measurement
        self.scale = scale
        self.ns = ns

    fn to_csv_row(self) -> String:
        """Convert to CSV row: product,gitcommit,epoch,benchmark,repeat,measurement,scale,ns."""
        var row = String("")
        row += self.product + ","
        row += self.gitcommit + ","
        row += String(self.epoch) + ","
        row += self.benchmark_uuid + ","
        row += String(self.repeat) + ","
        row += self.measurement + ","
        row += String(self.scale) + ","
        row += String(self.ns)
        return row


# ============================================================================
# BENCHMARK OPERATIONS
# ============================================================================

fn bench_insert(scale: Int) raises -> Int:
    """Benchmark insert operation: insert N sequential keys.

    Returns: Total time in nanoseconds.
    """
    var hamt = HAMT[Int, Int]()

    var start = perf_counter_ns()
    for i in range(scale):
        hamt[i] = i * 10
    var end = perf_counter_ns()

    # Verify
    assert_equal(len(hamt), scale, "Size mismatch after insert")

    return Int(end - start)


fn bench_query(scale: Int) raises -> Int:
    """Benchmark query operation: lookup all existing keys.

    Returns: Total time in nanoseconds.
    """
    var hamt = HAMT[Int, Int]()

    # Pre-populate
    for i in range(scale):
        hamt[i] = i * 10

    # Benchmark lookups
    var start = perf_counter_ns()
    for i in range(scale):
        var value = hamt[i]
        assert_equal(value, i * 10, "Value mismatch")
    var end = perf_counter_ns()

    return Int(end - start)


# ============================================================================
# BENCHMARK RUNNER
# ============================================================================

fn run_benchmark(
    measurement: String,
    scale: Int,
    repeat: Int,
    benchmark_uuid: String,
    gitcommit: String,
    epoch: Int
) raises -> BenchmarkResult:
    """Run a single benchmark and return the result.

    Args:
        measurement: Operation type ("insert", "query", etc.).
        scale: Number of entries to benchmark.
        repeat: Repetition number (0-9).
        benchmark_uuid: UUID for this benchmark session.
        gitcommit: Git commit hash.
        epoch: Unix timestamp.

    Returns:
        BenchmarkResult with timing in nanoseconds per operation.
    """
    var total_time_ns: Int = 0

    if measurement == "insert":
        total_time_ns = bench_insert(scale)
    elif measurement == "query":
        total_time_ns = bench_query(scale)
    else:
        print("ERROR: Unknown measurement type:", measurement)
        abort()

    # Calculate ns per operation
    var ns_per_op = Float64(total_time_ns) / Float64(scale)

    return BenchmarkResult(
        PRODUCT_NAME,
        gitcommit,
        epoch,
        benchmark_uuid,
        repeat,
        measurement,
        scale,
        ns_per_op
    )


fn save_results_to_csv(results: List[BenchmarkResult], filepath: String) raises:
    """Save benchmark results to CSV file matching hamt-bench format."""
    var csv_content = String("product,gitcommit,epoch,benchmark,repeat,measurement,scale,ns\n")

    for i in range(len(results)):
        csv_content += results[i].to_csv_row() + "\n"

    with open(filepath, "w") as f:
        f.write(csv_content)

    print("\n✓ Results saved to:", filepath)


fn print_summary(results: List[BenchmarkResult]):
    """Print a summary of benchmark results."""
    print("\n" + "─" * 80)
    print("BENCHMARK SUMMARY")
    print("─" * 80)
    print(
        "Measurement".ljust(12),
        "Scale".rjust(10),
        "Repeat".rjust(8),
        "ns/op".rjust(12),
        "ops/sec".rjust(15)
    )
    print("─" * 80)

    for i in range(len(results)):
        var r = results[i].copy()
        var ops_per_sec = 1_000_000_000.0 / r.ns if r.ns > 0 else 0.0
        print(
            r.measurement.ljust(12),
            String(r.scale).rjust(10),
            String(r.repeat).rjust(8),
            String(r.ns).rjust(12),
            String(Int(ops_per_sec)).rjust(15)
        )

    print("─" * 80)


# ============================================================================
# MAIN
# ============================================================================

fn main() raises:
    print("\n" + "═" * 80)
    print("  MOJO HAMT BENCHMARKS (hamt-bench compatible format)")
    print("═" * 80)

    # Get benchmark metadata
    var gitcommit = get_gitcommit()
    var epoch = get_epoch()
    var benchmark_uuid = generate_uuid()

    print("\nBenchmark session:")
    print("  Product:", PRODUCT_NAME)
    print("  Git commit:", gitcommit)
    print("  Epoch:", epoch)
    print("  UUID:", benchmark_uuid)
    print("  Repeats per benchmark:", NUM_REPEATS)

    # Define benchmark parameters matching hamt-bench
    var measurements = List[String]("insert", "query")

    # Parse scales from command line arguments or use defaults
    var scales = List[Int]()
    if len(argv()) > 1:
        # Parse scales from command line: bench_numbers.mojo 1000 10000 100000
        print("\nUsing scales from command line:")
        for i in range(1, len(argv())):
            var scale = atol(argv()[i])
            scales.append(scale)
            print("  -", scale)
    else:
        # Default scales
        print("\nUsing default scales (pass scales as arguments to customize):")
        scales = List[Int](1_000, 10_000, 100_000, 1_000_000)
        for i in range(len(scales)):
            print("  -", scales[i])

    # Store all results
    var results = List[BenchmarkResult]()

    print("\n" + "─" * 80)
    print("Running benchmarks...")
    print("─" * 80 + "\n")

    # Run all benchmarks
    for measurement_idx in range(len(measurements)):
        var measurement = measurements[measurement_idx]

        for scale_idx in range(len(scales)):
            var scale = scales[scale_idx]

            print("  Running", measurement, "at scale", scale)

            for repeat in range(NUM_REPEATS):
                var result = run_benchmark(
                    measurement,
                    scale,
                    repeat,
                    benchmark_uuid,
                    gitcommit,
                    epoch
                )

                # Print progress for first few repeats
                if repeat < 3:
                    print("    Repeat", repeat, ":", String(result.ns), "ns/op")

                results.append(result^)

            print("  ✓ Completed", measurement, "at scale", scale, "\n")

    # Print summary
    print_summary(results)

    # Save to CSV
    save_results_to_csv(results, "benchmarks/data/mojo_hamt_numbers.csv")

    print("\n" + "═" * 80)
    print("  BENCHMARKS COMPLETED")
    print("  Total measurements:", len(results))
    print("═" * 80 + "\n")
