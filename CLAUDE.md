# Agent Onboarding: mojo-learning (HAMT Implementation)

Welcome, agent. This guide provides the context and instructions needed to work on this project.

## 1. Project Overview

This project is a high-performance implementation of a **Hash Array Mapped Trie (HAMT)** written in the **Mojo** programming language. A HAMT is a persistent, memory-efficient data structure for key-value storage, offering performance comparable to traditional hash tables.

The implementation supports generic key-value types and provides a standard dictionary-like interface (`__getitem__`, `__setitem__`, `__len__`, etc.).

## 2. Technology Stack

- **Language**: [Mojo](https://www.modular.com/mojo)
- **Dependency & Environment Management**: [Pixi](https://pixi.sh/)

All necessary dependencies and tasks are defined in `pixi.toml`. You should use `pixi` for all project-related commands.

## 3. Project Structure

- `hamt.mojo`: The core source code for the HAMT data structure. This is the main implementation file.
- `test_hamt.mojo`: The test suite for the HAMT. It contains a comprehensive set of tests covering all features and edge cases.
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
pixi run mojo test_hamt.mojo
```
However, a more conventional pixi approach would be to have a `test` task. Based on the `pixi.toml` I've read, no such task is defined. You should rely on the command from the `README.md`. A successful run will print "All tests passed!".

## 5. Agent Task Guidelines

1.  **Analyze the Request**: Understand the user's goal (e.g., fix a bug, add a feature, refactor).
2.  **Consult the Code**: Read `hamt.mojo` to understand the relevant logic.
3.  **Consult the Tests**: Read `test_hamt.mojo` to see how existing features are tested. If you're adding a new feature, you should also add a new test case.
4.  **Modify the Code**: Apply the required changes to `hamt.mojo`.
5.  **Verify with Tests**: Run `pixi run mojo test_hamt.mojo`. If the tests fail, analyze the output and fix the code until all tests pass.
6.  **Report Completion**: Inform the user once the task is complete and verified.

## 6. TODO: Benchmarking Plan

The following high-level benchmarking plan, extracted from `README.md`, needs to be executed.

### 6.1. Benchmark Datasets

- **Synthetic Datasets**: 
  - Sequential integers
  - Random integers
  - Collision-prone keys
- **Real-World Datasets**:
  - Unix Dictionary Words
  - Mendeley Key-Value Store Benchmark Datasets (Twitter data)
  - EnWiki Titles Dataset

### 6.2. Operations to Benchmark

- Insert (`set`)
- Update (`set` on existing key)
- Lookup (both hits and misses)
- Contains (`in` operator)
- Mixed read/write workloads

### 6.3. Metrics to Track

- **Performance**: Throughput (ops/sec) and Latency (ns/op).
- **Memory**: Memory per entry (bytes/entry) and total footprint.
- **Structure**: Average tree depth, bitmap utilization, and collision rate.

### 6.4. Baseline Comparisons

- **`libhamt`** (C implementation)
- **Python's `ContextVars`**
- **Mojo's `Dict[K, V]`**