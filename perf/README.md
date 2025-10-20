# Perf Profiling Tools

Linux perf profiling script with automatic flame graph generation for performance analysis.

## Quick Start

```bash
# CPU profiling (on-CPU time)
./perf_profile.sh -t cpu -p <pid> -d 30

# Off-CPU profiling (I/O, locks, waiting)
./perf_profile.sh -t offcpu -p <pid> -d 30

# Memory profiling (allocation patterns)
./perf_profile.sh -t mem -p <pid> -d 30

# Profile command execution
./perf_profile.sh -t cpu -c "./my_program --arg" -d 60
```

## Features

- **CPU Profiling**: Identify CPU-intensive functions and hot paths
- **Off-CPU Profiling**: Find I/O bottlenecks and lock contention
- **Memory Profiling**: Analyze memory allocation and access patterns
- **Automatic Flame Graph Generation**: Interactive SVG visualization
- **Fast Symbol Resolution**: Support for gimli-rs addr2line
- **Built-in HTTP Server**: Instant flame graph viewing

## Profile Types

### CPU (On-CPU)
- **What**: Where CPU time is spent
- **Events**: `cpu-clock`
- **Use for**: Finding hot functions, algorithmic bottlenecks

### Off-CPU
- **What**: Where processes are blocked/waiting
- **Events**: `sched:sched_switch`
- **Use for**: I/O bottlenecks, lock contention, synchronization issues

### Memory
- **What**: Memory allocation and access patterns
- **Events**: `page-faults`, `minor-faults`, `major-faults`
- **Use for**: Allocation hot spots, memory-intensive operations

## Requirements

- Linux with perf support
- Perl (for FlameGraph scripts)
- FlameGraph tools (auto-installed if missing)
- Optional: Rust (for fast addr2line)

## Options

```
Required:
  -t TYPE               Profile type: cpu, offcpu, mem
  -p PID                Target process PID
  -c "COMMAND"          Command to run and profile

Optional:
  -d SECONDS            Duration in seconds (default: 60)
  -f FREQUENCY          Sampling frequency for CPU (default: 99Hz)
  -o DIR                Output directory (default: ./perf_output_<timestamp>)
  -g DIR                FlameGraph tools directory (auto-detected)
  -h                    Show help
```

## Examples

```bash
# Profile running server for 60 seconds
./perf_profile.sh -t cpu -p $(pgrep my_server) -d 60

# Profile test with high frequency
./perf_profile.sh -t cpu -c "./bin/my_test" -d 30 -f 199

# Find I/O bottlenecks
./perf_profile.sh -t offcpu -p 1234 -d 60

# Memory allocation analysis
./perf_profile.sh -t mem -c "./memory_intensive_app" -d 30

# Custom output directory
./perf_profile.sh -t cpu -p 1234 -d 30 -o /tmp/profiles
```

## Performance Tips

### Use Fast addr2line (Recommended)

Install gimli-rs for 5-10x faster symbol resolution:

```bash
cargo install addr2line --features bin
```

**Performance impact**:
- GNU addr2line: 2-5 minutes for large profiles
- gimli-rs addr2line: 20-60 seconds for same profiles

### Optimal Settings

- **Duration**: 30-60s for most cases
- **CPU frequency**: 99Hz (default), 199Hz for detailed analysis
- **Call graph**: dwarf (automatic fallback to fp)

## Output Files

All files are saved to the output directory:

- `perf_*.data` - Raw perf data (can be re-analyzed later)
- `*.folded` - Folded stack traces (intermediate format)
- `*.svg` - Interactive flame graph (open in browser)

## Troubleshooting

### No samples collected
```bash
# Increase duration
./perf_profile.sh -t cpu -p 1234 -d 120

# Verify process is active
top -p 1234
```

### Missing symbols (hex addresses)
```bash
# Build with debug symbols
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo

# Verify symbols exist
nm ./bin/my_program | grep -i main
```

### Conversion timeout
```bash
# Install fast addr2line
cargo install addr2line --features bin
```

### Permission denied
```bash
# The script uses sudo for perf commands
# Ensure sudo access is available
```

## Documentation

See [perf-profiling-guide.md](./perf-profiling-guide.md) for comprehensive documentation including:

- Detailed explanation of each profile type
- How memory profiling works (page fault tracking)
- Flame graph generation pipeline
- Performance optimization techniques
- Complete troubleshooting guide

## Resources

- [Brendan Gregg's Flame Graphs](http://www.brendangregg.com/flamegraphs.html)
- [Linux perf Wiki](https://perf.wiki.kernel.org/)
- [FlameGraph Tools](https://github.com/brendangregg/FlameGraph)
- [gimli-rs addr2line](https://github.com/gimli-rs/addr2line)
