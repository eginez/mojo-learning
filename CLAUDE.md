# Agent Onboarding: mojo-learning (HAMT Implementation)

Welcome, agent. This guide provides the context and instructions needed to work on this project.

## 1. Project Overview

This project is a high-performance implementation of a **Hash Array Mapped Trie (HAMT)** written in the **Mojo** programming language. A HAMT is a persistent, memory-efficient data structure for key-value storage, offering performance comparable to traditional hash tables.

The implementation supports generic key-value types and provides a standard dictionary-like interface (`__getitem__`, `__setitem__`, `__len__`, etc.).

**Performance Goal**: This implementation aims to benchmark competitively against [libhamt](https://github.com/mkirchner/hamt), a well-optimized C implementation of HAMT. Benchmark data from libhamt and other implementations (glib2, AVL trees, red-black trees, hsearch) is available in `db.sqlite` for comparison.

## 2. Technology Stack

- **Language**: [Mojo](https://www.modular.com/mojo)
- **Dependency & Environment Management**: [Pixi](https://pixi.sh/)

All necessary dependencies and tasks are defined in `pixi.toml`. You should use `pixi` for all project-related commands.

## 3. Project Structure

```
mojo-learning/
├── src/
│   └── mojo/
│       └── hamt.mojo          # Core HAMT implementation
├── tests/
│   └── mojo/
│       └── test_hamt.mojo     # Test suite
├── benchmarks/
│   ├── mojo/
│   │   └── bench_numbers.mojo    # hamt-bench compatible benchmarks
│   ├── python/                   # Python benchmarks (future)
│   └── data/
│       └── mojo_hamt_numbers.csv # Benchmark results (hamt-bench format)
├── db.sqlite                  # Reference benchmark database (hamt-bench)
├── pixi.toml                  # Pixi configuration
├── README.md                  # Main documentation
└── CLAUDE.md                  # Agent onboarding (this file)
```

### Key Files

- `src/mojo/hamt.mojo`: The core source code for the HAMT data structure. This is the main implementation file.
- `tests/mojo/test_hamt.mojo`: The test suite for the HAMT. It contains a comprehensive set of tests covering all features and edge cases.
- `benchmarks/mojo/bench_numbers.mojo`: Main benchmark suite compatible with [hamt-bench](https://github.com/mkirchner/hamt-bench) format. Supports command-line arguments for scale selection.
- `benchmarks/data/mojo_hamt_numbers.csv`: Benchmark results in hamt-bench format (product,gitcommit,epoch,benchmark,repeat,measurement,scale,ns).
- `db.sqlite`: Reference benchmark database from hamt-bench (AMD Ryzen 7, 26GB RAM). Contains libhamt, glib2, avl, rb, hsearch baseline results. **Note: These benchmarks were run on different hardware (AMD Ryzen 7) than the Mojo benchmarks (Apple Silicon), so direct performance comparisons should account for hardware differences.**
- `pixi.toml`: The project configuration file. It defines dependencies and tasks for building, running, and testing. The `[tasks]` in this file are especially important.
- `README.md`: The main project documentation, intended for human developers. It contains detailed information about architecture and benchmarking.

## 4. Development Workflow & Key Commands

The environment is managed by Pixi. Use the following commands to interact with the project.

### Setup

To install dependencies and set up the environment (if needed):
```bash
pixi install
```

### Running the Main Program

The `pixi.toml` does not define a default run command, but you can execute the main file directly:
```bash
mojo hamt.mojo
```

### **Testing (Most Important)**

The most critical command for you is the test command. **Always run the tests after making any changes to `hamt.mojo` to verify correctness.**

The `README.md` specifies the test command:
```bash
pixi run mojo tests/mojo/test_hamt.mojo
```
However, a more conventional pixi approach would be to have a `test` task. Based on the `pixi.toml` I've read, no such task is defined. You should rely on the command from the `README.md`. A successful run will print "All tests passed!".

### **Benchmarking**

To run benchmarks compatible with hamt-bench format:

```bash
# Run with specific scales (recommended for testing)
pixi run mojo run -I src/mojo benchmarks/mojo/bench_numbers.mojo 1000 10000

# Run with all default scales (1K, 10K, 100K, 1M - takes longer)
pixi run mojo run -I src/mojo benchmarks/mojo/bench_numbers.mojo 1000 10000 100000 1000000

# Or use defaults (no arguments = 1K, 10K, 100K, 1M)
pixi run mojo run -I src/mojo benchmarks/mojo/bench_numbers.mojo
```

This will:
1. Run insert and query benchmarks with 10 repetitions each
2. Print results to the console with summary statistics
3. Save results to `benchmarks/data/mojo_hamt_numbers.csv` in hamt-bench format

The CSV file can be loaded with pandas for analysis and comparison with libhamt:
```python
import pandas as pd
mojo_df = pd.read_csv('benchmarks/data/mojo_hamt_numbers.csv')
# Compare with libhamt data from db.sqlite
```

## 5. Agent Task Guidelines

1.  **Analyze the Request**: Understand the user's goal (e.g., fix a bug, add a feature, refactor).
2.  **Consult the Code**: Read `hamt.mojo` to understand the relevant logic.
3.  **Consult the Tests**: Read `test_hamt.mojo` to see how existing features are tested. If you're adding a new feature, you should also add a new test case.
4.  **Modify the Code**: Apply the required changes to `hamt.mojo`.
5.  **Verify with Tests**: Run `pixi run mojo test_hamt.mojo`. If the tests fail, analyze the output and fix the code until all tests pass.
6.  **Report Completion**: Inform the user once the task is complete and verified.

## 6. Benchmarking Plan

The following benchmarking plan is extracted from `README.md`.

### 6.1. Benchmark Datasets

#### 6.1.1 Synthetic Datasets ✅ IMPLEMENTED

**Location**: `benchmarks/mojo/bench_synthetic.mojo`  
**Output**: `benchmarks/data/synthetic_benchmarks.csv`

Implemented benchmarks:
- **Sequential integers**: Keys 0, 1, 2, ..., N (predictable hashing)
  - Sizes: 100, 1K, 10K, 100K, 1M entries
  - Operations: Insert, Lookup (hits/misses), Update, Contains
  
- **Random integers**: Uniform random Int64 (realistic distribution)
  - Sizes: 100, 1K, 10K, 100K, 1M entries
  - Operations: Insert, Lookup (hits/misses), Update
  
- **Collision-prone keys**: Custom hash forcing collisions (stress test)
  - Sizes: 1K, 10K, 100K entries
  - Operations: Insert, Lookup (hits), Update

**CSV Format**:
```
method,dataset_type,operation,size,total_time_ns,ops_per_sec,ns_per_op
mojo-hamt,Sequential Integers,Insert,1000,123456,8100000,123.4
...
```

The `method` column allows comparison between different implementations:
- `mojo-hamt`: This HAMT implementation
- `python-dict`: Python's built-in dict (future)
- `python-contextvar`: Python's ContextVars (future)
- `libhamt`: C implementation via CFFI (future)

#### 6.1.2 Real-World Datasets ⏳ TODO

- **Unix Dictionary Words** (235K words from `/usr/share/dict/words`)
- **Mendeley Key-Value Store Benchmark Datasets** (Twitter data)
- **EnWiki Titles Dataset** (15.9M Wikipedia article titles)

### 6.2. Operations to Benchmark

- Insert (`set`)
- Update (`set` on existing key)
- Lookup (both hits and misses)
- Contains (`in` operator)
- Mixed read/write workloads ⏳ TODO

### 6.3. Metrics to Track

Currently tracked:
- **Performance**: Throughput (ops/sec) and Latency (ns/op) ✅
- **Memory**: Memory per entry (bytes/entry) and total footprint ⏳ TODO
- **Structure**: Average tree depth, bitmap utilization, and collision rate ⏳ TODO

### 6.4. Baseline Comparisons ⏳ TODO

- **`libhamt`** (C implementation)
- **Python's `ContextVars`**
- **Mojo's `Dict[K, V]`**
