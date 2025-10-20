# Linux Perf Profiling Guide

This document explains the principles behind the `perf_profile.sh` script and how to effectively use Linux perf for performance analysis.

## Table of Contents

- [Overview](#overview)
- [Profile Types](#profile-types)
  - [CPU Profiling](#cpu-profiling)
  - [Off-CPU Profiling](#off-cpu-profiling)
  - [Memory Profiling](#memory-profiling)
- [How Memory Profiling Works](#how-memory-profiling-works)
- [Flame Graph Generation Pipeline](#flame-graph-generation-pipeline)
- [Performance Optimization Tips](#performance-optimization-tips)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)

## Overview

The `perf_profile.sh` script provides a convenient wrapper around Linux perf tool to generate flame graphs for performance analysis. It supports three types of profiling:

1. **CPU profiling** - Where CPU time is spent (on-CPU time)
2. **Off-CPU profiling** - Where processes are blocked/waiting (I/O, locks, etc.)
3. **Memory profiling** - Memory allocation and access patterns

## Profile Types

### CPU Profiling

**What it measures**: On-CPU execution time - which functions consume the most CPU cycles.

**How it works**:
- Uses sampling-based profiling with configurable frequency (default 99Hz)
- Periodically interrupts the program and records the call stack
- Event: `cpu-clock`
- Call graph mode: `dwarf` (detailed) or `fp` (frame pointer, faster)

**Use cases**:
- Find CPU-intensive functions
- Identify hot paths in your code
- Optimize algorithmic complexity
- Detect unexpected CPU usage

**Example**:
```bash
./scripts/perf_profile.sh -t cpu -p 1234 -d 30 -f 99
```

### Off-CPU Profiling

**What it measures**: Time spent blocked or waiting (not executing on CPU).

**How it works**:
- Tracks scheduler context switches
- Event: `sched:sched_switch`
- Records when processes are scheduled out (blocked)

**Use cases**:
- Find I/O bottlenecks (disk, network)
- Identify lock contention
- Detect excessive thread synchronization
- Analyze sleep/wait operations

**Example**:
```bash
./scripts/perf_profile.sh -t offcpu -p 1234 -d 30
```

### Memory Profiling

**What it measures**: Memory allocation and access patterns through page faults.

**How it works**:
- Tracks page fault events
- Events: `page-faults`, `minor-faults`, `major-faults`
- See [How Memory Profiling Works](#how-memory-profiling-works) for details

**Use cases**:
- Identify memory-intensive functions
- Find allocation hot spots
- Detect memory growth patterns
- Analyze memory access patterns

**Example**:
```bash
./scripts/perf_profile.sh -t mem -p 1234 -d 30
```

## How Memory Profiling Works

### The Two-Phase Memory Allocation Model

Understanding why page faults reflect memory usage requires understanding how Linux manages memory:

#### Phase 1: Virtual Memory Allocation (malloc/new)

```cpp
char* buffer = new char[1024 * 1024];  // 1MB allocation
// At this point: Kernel only reserves virtual address space
// Physical memory: 0 bytes allocated
```

When you call `malloc` or `new`, the kernel:
1. Reserves virtual address space
2. Records the reservation in process page tables
3. **Does NOT allocate physical memory yet**

This is called **lazy allocation** or **demand paging**.

#### Phase 2: Physical Memory Allocation (first access)

```cpp
buffer[0] = 'a';  // First write access
// NOW: Page fault is triggered!
// Kernel allocates actual physical memory page
// Maps virtual address to physical address
```

When you access the memory for the first time:
1. CPU tries to access virtual address
2. Page table has no physical mapping → **Page Fault**
3. Kernel allocates physical memory page (4KB typically)
4. Updates page table mapping
5. Instruction is retried and succeeds

### Why Lazy Allocation?

**Efficiency**: Many programs allocate more memory than they actually use.

```cpp
// Example: Overcommit
char* huge = new char[10GB];  // Succeeds even if only 8GB RAM available
// No physical memory used yet

memset(huge, 0, 10GB);  // NOW triggers massive page faults
// If insufficient memory, OOM killer may intervene
```

### Page Fault Types

#### Minor Page Fault

**Definition**: Page is in physical memory, but not in process page table.

**Scenarios**:
1. **First access to newly allocated memory**
```cpp
int* arr = new int[1000];
arr[0] = 42;  // Minor fault: allocate physical page, establish mapping
arr[1] = 43;  // Possible minor fault (if crosses page boundary)
```

2. **Copy-on-Write (COW)**
```cpp
pid_t pid = fork();
// Parent and child share physical pages (read-only)
if (pid == 0) {
    shared_data[0] = 1;  // Minor fault: copy page before write
}
```

3. **Memory-mapped file access (page in cache)**
```cpp
int fd = open("data.bin", O_RDONLY);
char* mapped = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
char first = mapped[0];  // Minor fault if page already in cache
```

#### Major Page Fault

**Definition**: Page needs to be loaded from disk.

**Scenarios**:
1. **Swap in**
```cpp
// Page was swapped out to disk
access_swapped_memory();  // Major fault: load from swap
```

2. **Memory-mapped file (not in cache)**
```cpp
int fd = open("data.bin", O_RDONLY);
char* mapped = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
char first = mapped[0];  // Major fault: read from disk into memory
```

### Why Page Faults Reflect Memory Usage

#### 1. Direct Correlation with Allocation

```cpp
// High page fault activity
for (int i = 0; i < 100; i++) {
    auto* obj = new MyLargeObject();  // Assume > 4KB
    obj->init();  // Triggers page faults on first access
}
// Flame graph shows: which function allocates lots of memory
```

#### 2. Memory Access Hot Spots

```cpp
void process_data() {
    std::vector<Data> vec;
    vec.reserve(1000000);  // Virtual address reservation only
    
    for (int i = 0; i < 1000000; i++) {
        vec.emplace_back(...);  // Each new element triggers page fault
        // Flame graph shows: process_data allocates heavily
    }
}
```

#### 3. Memory Growth Patterns

```cpp
// Memory leak scenario
void leak() {
    while (true) {
        auto* leaked = new char[4096];
        leaked[0] = 1;  // Page fault on each iteration
        // Forgot to delete
    }
}
// Flame graph shows: leak() continuously generates page faults
```

### What Page Fault Profiling Shows

#### ✅ Can See:

1. **Functions allocating large amounts of memory**
2. **Call stacks leading to allocations**
3. **Memory access intensive code paths**
4. **Stack growth** (deep recursion)
5. **File mmap access patterns**

**Example from TCQA codebase**:
```cpp
// src/filemeta/table_file_meta_mgr_test.cc
TEST(FileMetaMgr, CreateManyFiles) {
    for (int i = 0; i < 1000; i++) {
        auto meta = std::make_shared<FileMeta>(...);  
        meta->file_path = generate_path(i);  // Page fault
        meta->lsn = i;                        // Possible page fault
        file_metas.push_back(meta);
    }
}
```

**Flame graph would show**:
```
CreateManyFiles
  └─ std::make_shared
      └─ operator new
          └─ [high page fault count]
```

#### ❌ Cannot See:

1. **Allocated but unaccessed memory** (virtual != physical)
2. **Small object churn** (frequent alloc/free in same page)
3. **Memory deallocations** (free/delete don't trigger page faults)
4. **Precise memory usage numbers** (only trends)

### Comparison: Page Fault vs. Heap Profiling

| Feature | Page Fault Profiling | Heap Profiling (jemalloc) |
|---------|---------------------|---------------------------|
| **What it tracks** | Physical memory allocation | Heap allocator calls |
| **Granularity** | Page level (4KB) | Byte level |
| **Overhead** | Very low | Low to medium |
| **Setup** | No code changes | Requires jemalloc |
| **Sees deallocations** | No | Yes |
| **Best for** | Memory access patterns | Precise heap analysis |

**Recommendation**:
- Use **page fault profiling** for finding memory-intensive operations and allocation patterns
- Use **jemalloc profiling** (see `jemalloc_profile.sh`) for precise heap allocation analysis

## Flame Graph Generation Pipeline

The script generates flame graphs through the following pipeline:

### 1. Data Collection (`perf record`)

```bash
sudo perf record -o perf.data -e <event> -g -p <pid> -- sleep <duration>
```

**Output**: Binary `perf.data` file containing samples

### 2. Stack Extraction (`perf script`)

```bash
sudo perf script -i perf.data --demangle
```

**Process**:
- Converts binary data to text format
- Resolves symbols from binaries
- Demangling C++ symbols (slow with GNU addr2line)
- Resolves source line numbers via `addr2line`

**Output**: Text-based stack traces

**Performance bottleneck**: `addr2line` is called for every address
- GNU binutils version: Very slow (syscalls for each address)
- gimli-rs version: Much faster (Rust implementation)

### 3. Stack Folding (`stackcollapse-perf.pl`)

```bash
stackcollapse-perf.pl --all < perf_script_output
```

**Process**: Converts multi-line stacks to single-line format:

**Input**:
```
process 1234
    func_a
    func_b
    func_c
```

**Output**:
```
func_c;func_b;func_a 1
```

### 4. Flame Graph Generation (`flamegraph.pl`)

```bash
flamegraph.pl folded_stacks.txt > flamegraph.svg
```

**Process**: Generates interactive SVG visualization

**Features**:
- Horizontal width = time/sample count
- Stack depth = call hierarchy
- Colors = different code modules or types
- Interactive: Click to zoom, search functions

### Complete Pipeline Diagram

```
┌─────────────┐
│ perf record │ → perf.data (binary)
└─────────────┘
       ↓
┌─────────────┐
│ perf script │ → text stacks (with addr2line)
└─────────────┘              ↓
       ↓              ┌──────────────┐
       ↓              │ addr2line    │ (bottleneck!)
       ↓              └──────────────┘
┌──────────────────┐
│ stackcollapse.pl │ → folded stacks (single-line)
└──────────────────┘
       ↓
┌──────────────┐
│ flamegraph.pl│ → flamegraph.svg
└──────────────┘
```

## Performance Optimization Tips

### 1. Use Fast addr2line (gimli-rs)

The script includes detection and installation helper for the fast Rust-based addr2line:

**Check current version**:
```bash
addr2line --version
```

**Install gimli-rs version**:
```bash
cargo install addr2line --features bin
```

**Performance impact**:
- GNU addr2line: 2-5 minutes for large profiles
- gimli-rs addr2line: 20-60 seconds for same profiles

### 2. Skip Demangling for Speed

If symbols are not critical:
```bash
# Modify the script or manually run:
sudo perf script -i perf.data --no-demangle | stackcollapse-perf.pl
```

### 3. Disable Inline Info

```bash
sudo perf script -i perf.data --no-inline
```

Trades symbol detail for speed.

### 4. Adjust Timeouts

The script has built-in timeouts:
- Fast addr2line: 120s timeout
- Slow addr2line: 180s timeout

If needed, edit the script to increase timeout values.

## Usage Examples

### CPU Profiling: Find Hot Functions

```bash
# Profile running process
./scripts/perf_profile.sh -t cpu -p $(pgrep table_server) -d 60

# Profile test execution
./scripts/perf_profile.sh -t cpu -c "./bin/table_file_meta_mgr_test" -d 30
```

### Off-CPU Profiling: Find I/O Bottlenecks

```bash
# Profile process waiting on I/O
./scripts/perf_profile.sh -t offcpu -p 1234 -d 60
```

### Memory Profiling: Find Allocation Hot Spots

```bash
# Profile memory allocation patterns
./scripts/perf_profile.sh -t mem -p 1234 -d 30

# For precise heap profiling, use jemalloc instead:
./scripts/jemalloc_profile.sh -- ./bin/my_program
```

### Custom Output Directory

```bash
./scripts/perf_profile.sh -t cpu -p 1234 -d 30 -o /tmp/my_profiles
```

### Custom FlameGraph Location

```bash
./scripts/perf_profile.sh -t cpu -p 1234 -d 30 -g /path/to/FlameGraph
```

## Troubleshooting

### No Samples Collected

**Symptoms**: Empty flame graph or "no samples" error

**Causes**:
1. Process was idle during profiling
2. Duration too short
3. Insufficient permissions

**Solutions**:
```bash
# Longer duration
./scripts/perf_profile.sh -t cpu -p 1234 -d 120

# Check process is actually running
top -p 1234

# Verify perf data
sudo perf report -i perf.data
```

### Symbol Resolution Failed

**Symptoms**: Flame graph shows hex addresses instead of function names

**Causes**:
1. Binary stripped of symbols
2. Missing debug info
3. Wrong binary path

**Solutions**:
```bash
# Check if binary has symbols
nm ./bin/my_program | grep -i main

# Ensure debug build
cmake -DCMAKE_BUILD_TYPE=Debug

# For release builds, keep debug symbols
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo
```

### Conversion Timeout

**Symptoms**: Script kills conversion after timeout

**Causes**:
1. Very large perf.data file
2. Slow addr2line

**Solutions**:
```bash
# Install fast addr2line
cargo install addr2line --features bin

# Or increase timeout in script (edit perf_profile.sh):
timeout1=300  # Increase from 120s
```

### Lambda Functions Not Demangled

**Symptoms**: Seeing mangled lambda names like `_ZZZN4tcqa...`

**Causes**: Lambda functions have very long mangled names that sometimes don't demangle fully

**Nature**: This is expected - lambdas contain full template parameters and capture lists

**Example**:
```
_ZZZN4tcqa5table6common16CommonThreadPool18SubmitWithSyncWaitIZNS0_8filemeta19CheckpointGenerator3runEPvEUlvE_
```

Represents:
```cpp
tcqa::table::common::CommonThreadPool::SubmitWithSyncWait<
  tcqa::table::filemeta::CheckpointGenerator::run(void*)::{lambda()#1}
>(...)
```

**Solutions**:
1. Use named function objects instead of lambdas for hot paths
2. Focus on the demangled portion (class/method names)
3. Accept that lambda symbols are verbose by nature

## References

- [Brendan Gregg's Flame Graphs](http://www.brendangregg.com/flamegraphs.html)
- [Linux perf Wiki](https://perf.wiki.kernel.org/)
- [gimli-rs addr2line](https://github.com/gimli-rs/addr2line)
- [Understanding Linux Memory Management](https://www.kernel.org/doc/html/latest/admin-guide/mm/index.html)