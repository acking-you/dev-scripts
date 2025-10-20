#!/bin/bash

# Linux perf profiling tool with flame graph generation
# Supports CPU profiling (on-CPU/off-CPU) and memory profiling
# Automatically generates flame graphs for visualization
#
# Usage examples:
#   ./perf_profile.sh -t cpu -p 1234 -d 30
#   ./perf_profile.sh -t cpu -c "./my_program --arg" -d 60
#   ./perf_profile.sh -t mem -p 1234 -d 30
#   ./perf_profile.sh -t offcpu -c "./my_program" -d 60

set -e
set -u
set -o pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_DURATION=60
DEFAULT_FREQ=99
FLAMEGRAPH_REPO="https://github.com/brendangregg/FlameGraph.git"
FLAMEGRAPH_DIR_NAME="FlameGraph_Repo"

# Global variables
CMD_PID=""
PERF_DATA_FILE=""
FOLDED_STACKS_FILE=""
SVG_OUTPUT_FILE=""
SVG_OUTPUT_DIR=""

function show_help() {
    echo -e "${GREEN}Linux Perf Profiling Tool${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "    $0 -t <profile_type> [-d <duration>] [-f <frequency>] [-o <output_dir>] [-g <flamegraph_dir>] (-p <pid> | -c \"<command>\")"
    echo ""
    echo -e "${YELLOW}Required Options:${NC}"
    echo "    -t TYPE               Profile type: cpu, offcpu, mem"
    echo "    -p PID                Target process PID to profile"
    echo "    -c \"COMMAND\"          Command to run and profile (quoted)"
    echo ""
    echo -e "${YELLOW}Optional Options:${NC}"
    echo "    -d SECONDS            Duration in seconds (default: ${DEFAULT_DURATION})"
    echo "    -f FREQUENCY          Sampling frequency for CPU profiling (default: ${DEFAULT_FREQ})"
    echo "    -o DIR                Output directory (default: ./perf_output_<timestamp>)"
    echo "    -g DIR                FlameGraph tools directory (default: auto-detect or clone)"
    echo "    -h                    Show this help message"
    echo ""
    echo -e "${YELLOW}Profile Types:${NC}"
    echo "    cpu                   On-CPU profiling (where CPU time is spent)"
    echo "    offcpu                Off-CPU profiling (where processes are blocked/waiting)"
    echo "    mem                   Memory allocation profiling"
    echo ""
    echo -e "${YELLOW}Environment Variables:${NC}"
    echo "    FLAMEGRAPH_DIR        FlameGraph tools directory (overridden by -g option)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "    # Profile existing process CPU usage for 30 seconds"
    echo "    $0 -t cpu -p 1234 -d 30"
    echo ""
    echo "    # Profile command execution with custom frequency"
    echo "    $0 -t cpu -c \"./my_program --arg\" -d 60 -f 199"
    echo ""
    echo "    # Profile with custom FlameGraph directory"
    echo "    $0 -t cpu -p 1234 -d 30 -g /path/to/FlameGraph"
    echo ""
    echo "    # Profile memory allocations"
    echo "    $0 -t mem -p 1234 -d 30"
    echo ""
    echo "    # Profile off-CPU time (I/O, locks, etc.)"
    echo "    $0 -t offcpu -c \"./my_program\" -d 30"
    echo ""
}

function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

function cleanup_intermediate_files() {
    # Keep all files for user inspection
    return 0
}

function cleanup_background_command() {
    if [ -n "$CMD_PID" ] && ps -p "$CMD_PID" > /dev/null 2>&1; then
        log_info "Stopping background command with PID $CMD_PID"
        kill "$CMD_PID" 2>/dev/null || true
        sleep 0.5
        if ps -p "$CMD_PID" > /dev/null 2>&1; then
            log_warn "Sending SIGKILL to PID $CMD_PID"
            kill -9 "$CMD_PID" 2>/dev/null || true
        fi
    fi
}

function handle_interrupt() {
    echo ""
    log_warn "Interrupted by user (Ctrl+C)"
    log_info "Cleaning up..."
    cleanup_background_command
    cleanup_intermediate_files
    log_info "Exiting"
    exit 130
}

trap 'handle_interrupt' INT
trap 'cleanup_background_command' EXIT TERM

function install_fast_addr2line() {
    log_info "Installing fast addr2line (gimli-rs)..."
    echo ""
    
    # Check if cargo is available
    if ! command -v cargo &> /dev/null; then
        log_error "cargo not found. Please install Rust first:"
        log_warn "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        log_warn "Or visit: https://rustup.rs/"
        echo ""
        log_info "After installing Rust, install addr2line with:"
        log_warn "  cargo install addr2line --features bin"
        return 1
    fi
    
    log_info "Found cargo: $(which cargo)"
    echo ""
    
    # Ask user for confirmation
    read -p "Install fast addr2line (gimli-rs) via cargo? This may take a few minutes. [Y/n] " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Installation cancelled"
        log_info "To install manually, run: cargo install addr2line --features bin"
        return 1
    fi
    
    # Determine installation directory
    local install_dir=""
    if command -v addr2line &> /dev/null; then
        local existing_addr2line=$(which addr2line)
        install_dir=$(dirname "$existing_addr2line")
        log_info "Found existing addr2line at: $existing_addr2line"
        log_info "Will replace it after installation"
    else
        install_dir="/usr/local/bin"
        log_info "Will install to: $install_dir"
    fi
    
    local temp_dir=$(mktemp -d)
    
    # Install via cargo to temp location
    log_info "Installing addr2line via cargo (this may take a few minutes)..."
    if ! cargo install addr2line --features bin --root "$temp_dir"; then
        log_error "Cargo installation failed"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Verify it works
    if [ ! -f "$temp_dir/bin/addr2line" ]; then
        log_error "addr2line binary not found after installation"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_info "Verifying installed binary:"
    "$temp_dir/bin/addr2line" --version
    echo ""
    
    # Backup existing addr2line if it exists
    if [ -f "$install_dir/addr2line" ]; then
        log_info "Backing up existing addr2line to ${install_dir}/addr2line.backup"
        sudo mv "$install_dir/addr2line" "${install_dir}/addr2line.backup"
    fi
    
    # Install new addr2line
    log_info "Installing to $install_dir/addr2line"
    if sudo mv "$temp_dir/bin/addr2line" "$install_dir/addr2line"; then
        log_info "✓ Successfully installed fast addr2line (gimli-rs)"
        log_info "New addr2line version:"
        addr2line --version
    else
        log_error "Failed to install to $install_dir"
        log_warn "You may need appropriate permissions"
        rm -rf "$temp_dir"
        return 1
    fi
    
    rm -rf "$temp_dir"
    echo ""
    return 0
}

function check_dependencies() {
    local custom_flamegraph_dir="$1"
    
    echo "" >&2
    echo "========================================" >&2
    log_info "Checking dependencies..."
    echo "========================================" >&2
    echo "" >&2
    
    # Check for perf
    if ! command -v perf &> /dev/null; then
        log_error "perf command not found"
        echo "" >&2
        log_warn "To install perf, run one of the following:" >&2
        log_warn "  Ubuntu/Debian: sudo apt-get install linux-tools-common linux-tools-generic linux-tools-\$(uname -r)" >&2
        log_warn "  CentOS/RHEL:   sudo yum install perf" >&2
        log_warn "  Fedora:        sudo dnf install perf" >&2
        echo "" >&2
        exit 1
    fi
    log_info "✓ perf is available: $(which perf)"
    
    # Check for perl (required by FlameGraph scripts)
    if ! command -v perl &> /dev/null; then
        log_error "perl command not found (required by FlameGraph)"
        echo "" >&2
        log_warn "To install perl, run:" >&2
        log_warn "  Ubuntu/Debian: sudo apt-get install perl" >&2
        log_warn "  CentOS/RHEL:   sudo yum install perl" >&2
        log_warn "  Fedora:        sudo dnf install perl" >&2
        echo "" >&2
        exit 1
    fi
    log_info "✓ perl is available: $(which perl)"
    
    # Check for addr2line (prefer gimli-rs version)
    local addr2line_path=""
    if command -v addr2line &> /dev/null; then
        addr2line_path=$(which addr2line)
        local addr2line_version=$(addr2line --version 2>&1 || echo "unknown")
        # Check if it's the fast gimli-rs version by looking for "addr2line" with version number
        # gimli-rs version output: "addr2line 0.x.x"
        # GNU binutils version output: "GNU addr2line (GNU Binutils) 2.x"
        if echo "$addr2line_version" | grep -q "^addr2line [0-9]"; then
            log_info "✓ Fast addr2line (gimli-rs) is available: $addr2line_path"
            log_info "  Version: $addr2line_version"
        else
            log_warn "System addr2line found (slow): $addr2line_path"
            log_warn "  Version: $addr2line_version"
            log_warn "Consider installing gimli-rs addr2line for better performance:"
            log_warn "  cargo install addr2line --features bin"
        fi
    else
        log_warn "addr2line not found. Symbol resolution may be limited."
    fi
    
    # Determine FlameGraph directory
    local flamegraph_path=""
    
    if [ -n "$custom_flamegraph_dir" ]; then
        # User specified custom directory
        flamegraph_path="$custom_flamegraph_dir"
        log_info "Using custom FlameGraph directory: $flamegraph_path"
    else
        # Try to find FlameGraph in common locations
        local script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
        local candidates=(
            "${script_dir}/${FLAMEGRAPH_DIR_NAME}"
            "${script_dir}/FlameGraph"
            "$(pwd)/FlameGraph"
            "$HOME/FlameGraph"
        )
        
        for candidate in "${candidates[@]}"; do
            if [ -d "$candidate" ] && [ -f "$candidate/flamegraph.pl" ] && [ -f "$candidate/stackcollapse-perf.pl" ]; then
                flamegraph_path="$candidate"
                log_info "Found FlameGraph at: $flamegraph_path"
                break
            fi
        done
        
        # If not found, offer to clone
        if [ -z "$flamegraph_path" ]; then
            log_warn "FlameGraph tools not found in common locations"
            echo "" >&2
            
            if ! command -v git &> /dev/null; then
                log_error "git command not found (required to clone FlameGraph)"
                echo "" >&2
                log_warn "Please either:" >&2
                log_warn "  1. Install git and re-run this script" >&2
                log_warn "  2. Manually clone FlameGraph: git clone https://github.com/brendangregg/FlameGraph.git" >&2
                log_warn "  3. Specify FlameGraph location with -g option" >&2
                echo "" >&2
                exit 1
            fi
            
            local default_path="${script_dir}/${FLAMEGRAPH_DIR_NAME}"
            log_warn "FlameGraph will be cloned to: $default_path"
            read -p "Continue? [Y/n] " -n 1 -r >&2
            echo "" >&2
            
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                log_error "FlameGraph is required. Please install it manually or use -g option."
                exit 1
            fi
            
            log_info "Cloning FlameGraph from GitHub..."
            if git clone "$FLAMEGRAPH_REPO" "$default_path" >&2; then
                flamegraph_path="$default_path"
                log_info "✓ FlameGraph cloned successfully"
            else
                log_error "Failed to clone FlameGraph repository"
                exit 1
            fi
        fi
    fi
    
    # Verify FlameGraph installation
    if [ ! -d "$flamegraph_path" ]; then
        log_error "FlameGraph directory does not exist: $flamegraph_path"
        exit 1
    fi
    
    if [ ! -f "$flamegraph_path/flamegraph.pl" ]; then
        log_error "flamegraph.pl not found in: $flamegraph_path"
        log_warn "Please ensure FlameGraph is properly installed"
        exit 1
    fi
    
    if [ ! -f "$flamegraph_path/stackcollapse-perf.pl" ]; then
        log_error "stackcollapse-perf.pl not found in: $flamegraph_path"
        log_warn "Please ensure FlameGraph is properly installed"
        exit 1
    fi
    
    log_info "✓ FlameGraph scripts available: $flamegraph_path"
    
    echo "" >&2
    echo "$flamegraph_path"
}

function setup_output_files() {
    local profile_type=$1
    local identifier=$2
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [ -z "$OUTPUT_DIR" ]; then
        OUTPUT_DIR="$(pwd)/perf_output_${timestamp}"
    fi
    
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)
    
    SVG_OUTPUT_DIR="$OUTPUT_DIR"
    PERF_DATA_FILE="${OUTPUT_DIR}/perf_${identifier}_${profile_type}_${timestamp}.data"
    FOLDED_STACKS_FILE="${OUTPUT_DIR}/${identifier}_${profile_type}_${timestamp}.folded"
    SVG_OUTPUT_FILE="${OUTPUT_DIR}/${profile_type}_${identifier}_${timestamp}.svg"
    
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Perf data file: $PERF_DATA_FILE"
    log_info "Flame graph: $SVG_OUTPUT_FILE"
}

function run_cpu_profiling() {
    local target_type=$1  # "pid" or "cmd"
    local target=$2       # PID number or command string
    local duration=$3
    local frequency=$4
    
    log_info "Starting CPU profiling (frequency: ${frequency}Hz, duration: ${duration}s)..."
    echo ""
    
    # Try dwarf first, fallback to fp if it fails
    local callgraph_mode="dwarf"
    if [ "$target_type" == "pid" ]; then
        log_info "Executing: sudo perf record -o \"$PERF_DATA_FILE\" -F $frequency -p $target -e cpu-clock --call-graph $callgraph_mode -g -- sleep $duration"
        sudo perf record -o "$PERF_DATA_FILE" -F "$frequency" -p "$target" \
            -e cpu-clock --call-graph "$callgraph_mode" -g -- sleep "$duration" 2>&1 | tee /tmp/perf_record_err.log
        
        # Check for dwarf issues and retry with fp
        if [ $? -ne 0 ] || grep -q "DWARF" /tmp/perf_record_err.log; then
            log_warn "DWARF call graph failed, retrying with frame pointer (fp)..."
            callgraph_mode="fp"
            log_info "Executing: sudo perf record -o \"$PERF_DATA_FILE\" -F $frequency -p $target -e cpu-clock --call-graph $callgraph_mode -g -- sleep $duration"
            sudo perf record -o "$PERF_DATA_FILE" -F "$frequency" -p "$target" \
                -e cpu-clock --call-graph "$callgraph_mode" -g -- sleep "$duration"
        fi
    else
        log_info "Executing: sudo perf record -o \"$PERF_DATA_FILE\" -F $frequency -e cpu-clock --call-graph $callgraph_mode -g -- bash -c \"$target\""
        sudo perf record -o "$PERF_DATA_FILE" -F "$frequency" -e cpu-clock \
            --call-graph "$callgraph_mode" -g -- bash -c "$target" 2>&1 | tee /tmp/perf_record_err.log
        
        if [ $? -ne 0 ] || grep -q "DWARF" /tmp/perf_record_err.log; then
            log_warn "DWARF call graph failed, retrying with frame pointer (fp)..."
            callgraph_mode="fp"
            log_info "Executing: sudo perf record -o \"$PERF_DATA_FILE\" -F $frequency -e cpu-clock --call-graph $callgraph_mode -g -- bash -c \"$target\""
            sudo perf record -o "$PERF_DATA_FILE" -F "$frequency" -e cpu-clock \
                --call-graph "$callgraph_mode" -g -- bash -c "$target"
        fi
    fi
    echo ""
    
    rm -f /tmp/perf_record_err.log
    
    if [ $? -ne 0 ] || [ ! -s "$PERF_DATA_FILE" ]; then
        log_error "CPU profiling failed or produced no data"
        return 1
    fi
    
    log_info "✓ CPU profiling completed using $callgraph_mode call graph"
    return 0
}

function run_offcpu_profiling() {
    local target_type=$1
    local target=$2
    local duration=$3
    
    log_info "Starting off-CPU profiling (duration: ${duration}s)..."
    echo ""
    
    if [ "$target_type" == "pid" ]; then
        log_info "Executing: sudo perf record -o \"$PERF_DATA_FILE\" -e sched:sched_switch -p $target -g -- sleep $duration"
        sudo perf record -o "$PERF_DATA_FILE" -e sched:sched_switch \
            -p "$target" -g -- sleep "$duration"
    else
        log_info "Executing: sudo perf record -o \"$PERF_DATA_FILE\" -e sched:sched_switch -g -- bash -c \"$target\""
        sudo perf record -o "$PERF_DATA_FILE" -e sched:sched_switch \
            -g -- bash -c "$target"
    fi
    echo ""
    
    if [ $? -ne 0 ] || [ ! -s "$PERF_DATA_FILE" ]; then
        log_error "Off-CPU profiling failed or produced no data"
        return 1
    fi
    
    log_info "✓ Off-CPU profiling completed"
    return 0
}

function run_mem_profiling() {
    local target_type=$1
    local target=$2
    local duration=$3
    
    log_info "Starting memory profiling (duration: ${duration}s)..."
    log_info "Using page-faults events (tracks memory allocation and access)"
    echo ""
    
    # Use page-faults to track memory allocation and access patterns
    # Page faults occur when newly allocated memory is accessed for the first time
    # This includes malloc/new, mmap, stack growth, etc.
    # More reliable than cache-misses and works on all systems
    if [ "$target_type" == "pid" ]; then
        log_info "Executing: sudo perf record -o \"$PERF_DATA_FILE\" -e page-faults,minor-faults,major-faults -g -p $target -- sleep $duration"
        sudo perf record -o "$PERF_DATA_FILE" -e page-faults,minor-faults,major-faults \
            -g -p "$target" -- sleep "$duration"
    else
        log_info "Executing: sudo perf record -o \"$PERF_DATA_FILE\" -e page-faults,minor-faults,major-faults -g -- bash -c \"$target\""
        sudo perf record -o "$PERF_DATA_FILE" -e page-faults,minor-faults,major-faults \
            -g -- bash -c "$target"
    fi
    echo ""
    
    if [ $? -ne 0 ] || [ ! -s "$PERF_DATA_FILE" ]; then
        log_error "Memory profiling failed or produced no data"
        log_warn "Note: For detailed heap profiling, use jemalloc profiling script instead"
        return 1
    fi
    
    log_info "✓ Memory profiling completed (page-faults events)"
    log_info "Note: Shows memory allocation patterns. For heap profiling, use jemalloc script."
    return 0
}

function generate_flamegraph() {
    local flamegraph_path=$1
    local profile_type=$2
    local title=$3
    
    log_info "Generating flame graph..."
    
    # Quick check if perf data file has content (skip perf report check as it can be very slow)
    local perf_data_size=$(stat -f%z "$PERF_DATA_FILE" 2>/dev/null || stat -c%s "$PERF_DATA_FILE" 2>/dev/null || echo 0)
    if [ "$perf_data_size" -lt 1024 ]; then
        log_error "Perf data file is too small (${perf_data_size} bytes), likely no samples collected"
        log_warn "Possible causes:"
        log_warn "  1. Profiling duration too short"
        log_warn "  2. Process was idle during profiling"
        log_warn "  3. Insufficient permissions"
        return 1
    fi
    log_info "Perf data file size: $(echo "scale=2; $perf_data_size / 1024 / 1024" | bc 2>/dev/null || echo "N/A") MB"
    
    # Try multiple methods to generate folded stacks
    log_info "Converting perf data to folded stacks..."
    log_warn "This may take a while for large data files. Press Ctrl+C to cancel."
    echo ""
    
    # Check if we have fast addr2line (gimli-rs)
    local use_demangle="--demangle"
    local timeout1=120
    local timeout2=180
    if command -v addr2line &> /dev/null; then
        local addr2line_version=$(addr2line --version 2>&1 || echo "unknown")
        if echo "$addr2line_version" | grep -q "^addr2line [0-9]"; then
            log_info "Using fast addr2line (gimli-rs) - enabling demangling"
        else
            log_warn "Using system addr2line (slow) - may take longer"
            timeout1=180
            timeout2=300
        fi
    else
        log_warn "No addr2line found - disabling demangling"
        use_demangle="--no-demangle"
    fi
    
    # Method 1: With demangling (fast if using gimli-rs)
    log_info "Method 1: Standard conversion with symbol resolution"
    echo "  Command: sudo perf script -i \"$PERF_DATA_FILE\" $use_demangle 2>/dev/null | \"$flamegraph_path/stackcollapse-perf.pl\" --all > \"$FOLDED_STACKS_FILE\""
    
    # Run in background with progress monitoring
    (sudo perf script -i "$PERF_DATA_FILE" $use_demangle 2>/dev/null | \
        "$flamegraph_path/stackcollapse-perf.pl" --all > "$FOLDED_STACKS_FILE" 2>&1) &
    local bg_pid=$!
    
    # Monitor progress with timeout
    local elapsed=0
    while ps -p $bg_pid > /dev/null 2>&1; do
        if [ $elapsed -ge $timeout1 ]; then
            log_warn "Conversion exceeded ${timeout1}s timeout, killing..."
            kill -9 $bg_pid 2>/dev/null || true
            # Also kill sudo perf process
            pkill -9 -f "perf script.*$PERF_DATA_FILE" 2>/dev/null || true
            wait $bg_pid 2>/dev/null || true
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        if [ $((elapsed % 10)) -eq 0 ]; then
            log_info "  Still converting... (${elapsed}s/${timeout1}s)"
        fi
    done
    
    # Wait for completion
    wait $bg_pid 2>/dev/null || true
    
    if [ -s "$FOLDED_STACKS_FILE" ]; then
        log_info "✓ Successfully generated folded stacks with symbol resolution"
    else
        log_warn "Standard conversion timed out or failed after ${timeout1}s"
    fi
    
    # Method 2: Without inline info (if Method 1 failed)
    if [ ! -s "$FOLDED_STACKS_FILE" ]; then
        echo ""
        log_warn "Trying without inline info (faster)..."
        log_info "Method 2: Conversion without inline info"
        echo "  Command: sudo perf script -i \"$PERF_DATA_FILE\" --no-inline 2>/dev/null | \"$flamegraph_path/stackcollapse-perf.pl\" --all > \"$FOLDED_STACKS_FILE\""
        
        # Run in background with progress monitoring
        (sudo perf script -i "$PERF_DATA_FILE" --no-inline 2>/dev/null | \
            "$flamegraph_path/stackcollapse-perf.pl" --all > "$FOLDED_STACKS_FILE" 2>&1) &
        bg_pid=$!
        
        # Monitor progress with timeout
        elapsed=0
        while ps -p $bg_pid > /dev/null 2>&1; do
            if [ $elapsed -ge $timeout2 ]; then
                log_warn "Conversion exceeded ${timeout2}s timeout, killing..."
                kill -9 $bg_pid 2>/dev/null || true
                # Also kill sudo perf process
                pkill -9 -f "perf script.*$PERF_DATA_FILE" 2>/dev/null || true
                wait $bg_pid 2>/dev/null || true
                break
            fi
            sleep 2
            elapsed=$((elapsed + 2))
            if [ $((elapsed % 10)) -eq 0 ]; then
                log_info "  Still converting... (${elapsed}s/${timeout2}s)"
            fi
        done
        
        # Wait for completion
        wait $bg_pid 2>/dev/null || true
        
        if [ -s "$FOLDED_STACKS_FILE" ]; then
            log_info "✓ Successfully generated folded stacks without inline info"
        else
            log_warn "Conversion timed out or failed after ${timeout2}s"
        fi
    fi
    
    # Method 3: Try with kernel symbols only
    if [ ! -s "$FOLDED_STACKS_FILE" ]; then
        echo ""
        log_warn "Trying with kernel symbols only..."
        log_info "Method 3: Conversion with kernel symbols only"
        echo "  Command: sudo perf script -i \"$PERF_DATA_FILE\" --hide-unresolved 2>/dev/null | \"$flamegraph_path/stackcollapse-perf.pl\" --all > \"$FOLDED_STACKS_FILE\""
        if sudo perf script -i "$PERF_DATA_FILE" --hide-unresolved 2>/dev/null | \
            "$flamegraph_path/stackcollapse-perf.pl" --all > "$FOLDED_STACKS_FILE" 2>&1; then
            if [ -s "$FOLDED_STACKS_FILE" ]; then
                log_info "✓ Generated folded stacks with kernel symbols only"
            fi
        fi
    fi
    echo ""
    
    if [ ! -s "$FOLDED_STACKS_FILE" ]; then
        log_error "Failed to generate folded stacks after trying all methods"
        echo ""
        log_warn "========== Diagnostic Information =========="
        log_info "Perf data file: $PERF_DATA_FILE"
        log_info "Perf data file size: $(ls -lh "$PERF_DATA_FILE" 2>/dev/null | awk '{print $5}' || echo 'unknown')"
        echo ""
        log_info "Testing perf script output (first 10 lines):"
        sudo perf script -i "$PERF_DATA_FILE" --no-inline 2>&1 | head -10 || echo "  [perf script failed]"
        echo ""
        log_warn "========== Troubleshooting Steps =========="
        log_warn "  1. Verify perf collected data: sudo perf report -i $PERF_DATA_FILE"
        log_warn "  2. Check if process was active during profiling"
        log_warn "  3. Try longer duration: -d 60"
        log_warn "  4. For CPU profiling, ensure process is using CPU"
        log_warn "  5. Check permissions: may need to run as root"
        log_warn "  6. Try frame-pointer instead: export with -g flag disabled"
        return 1
    fi
    
    # Generate flame graph based on type
    log_info "Generating SVG flame graph..."
    
    # Verify flamegraph.pl exists
    if [ ! -f "$flamegraph_path/flamegraph.pl" ]; then
        log_error "flamegraph.pl not found at: $flamegraph_path/flamegraph.pl"
        log_info "FlameGraph path: $flamegraph_path"
        log_info "Directory contents:"
        ls -la "$flamegraph_path/" 2>&1 | head -10
        return 1
    fi
    
    case "$profile_type" in
        cpu)
            echo "  Command: \"$flamegraph_path/flamegraph.pl\" --title=\"On-CPU Flame Graph - $title\" --countname=samples \"$FOLDED_STACKS_FILE\" > \"$SVG_OUTPUT_FILE\""
            perl "$flamegraph_path/flamegraph.pl" \
                --title="On-CPU Flame Graph - $title" \
                --countname=samples \
                "$FOLDED_STACKS_FILE" > "$SVG_OUTPUT_FILE"
            ;;
        offcpu)
            echo "  Command: \"$flamegraph_path/flamegraph.pl\" --title=\"Off-CPU Flame Graph - $title\" --countname=us --color=io \"$FOLDED_STACKS_FILE\" > \"$SVG_OUTPUT_FILE\""
            perl "$flamegraph_path/flamegraph.pl" \
                --title="Off-CPU Flame Graph - $title" \
                --countname=us \
                --color=io \
                "$FOLDED_STACKS_FILE" > "$SVG_OUTPUT_FILE"
            ;;
        mem)
            echo "  Command: \"$flamegraph_path/flamegraph.pl\" --title=\"Memory Allocation Flame Graph - $title\" --countname=calls --color=mem \"$FOLDED_STACKS_FILE\" > \"$SVG_OUTPUT_FILE\""
            perl "$flamegraph_path/flamegraph.pl" \
                --title="Memory Allocation Flame Graph - $title" \
                --countname=calls \
                --color=mem \
                "$FOLDED_STACKS_FILE" > "$SVG_OUTPUT_FILE"
            ;;
    esac
    
    if [ $? -ne 0 ]; then
        log_error "flamegraph.pl execution failed"
        return 1
    fi
    
    if [ ! -s "$SVG_OUTPUT_FILE" ]; then
        log_error "Failed to generate flame graph SVG"
        return 1
    fi
    
    log_info "✓ Flame graph generated: $SVG_OUTPUT_FILE"
    return 0
}

function serve_flamegraph() {
    local svg_file=$1
    local svg_dir=$(dirname "$svg_file")
    local svg_basename=$(basename "$svg_file")
    
    local python_exe=""
    if command -v python3 &> /dev/null; then
        python_exe="python3"
    elif command -v python &> /dev/null; then
        python_exe="python"
    fi
    
    if [ -z "$python_exe" ]; then
        log_warn "Python not found, cannot start HTTP server"
        log_info "Please open the flame graph manually: $svg_file"
        return 1
    fi
    
    local http_port=8000
    local original_pwd=$(pwd)
    
    echo ""
    echo "========================================"
    log_info "Starting HTTP server to view flame graph"
    echo "========================================"
    echo ""
    echo -e "  URL: ${BLUE}http://localhost:$http_port/$svg_basename${NC}"
    echo ""
    echo "  Open the URL above in your web browser"
    echo "  Press Ctrl+C to stop the server"
    echo ""
    echo "========================================"
    
    cd "$svg_dir" || {
        log_error "Could not change to output directory"
        cd "$original_pwd"
        return 1
    }
    
    if [ "$python_exe" == "python3" ]; then
        "$python_exe" -m http.server "$http_port"
    else
        "$python_exe" -m SimpleHTTPServer "$http_port"
    fi
    
    log_info "HTTP server stopped"
    cd "$original_pwd"
}

# Parse command line arguments
PID_ARG=""
COMMAND_STRING=""
PROFILE_TYPE=""
DURATION=""
FREQUENCY=""
OUTPUT_DIR=""
FLAMEGRAPH_DIR="${FLAMEGRAPH_DIR:-}"

while getopts "t:p:c:d:f:o:g:h" opt; do
    case $opt in
        t) PROFILE_TYPE="$OPTARG" ;;
        p) PID_ARG="$OPTARG" ;;
        c) COMMAND_STRING="$OPTARG" ;;
        d) DURATION="$OPTARG" ;;
        f) FREQUENCY="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        g) FLAMEGRAPH_DIR="$OPTARG" ;;
        h) show_help; exit 0 ;;
        *) show_help; exit 1 ;;
    esac
done

# Validate arguments
if [ -z "$PROFILE_TYPE" ]; then
    log_error "Profile type (-t) is required"
    show_help
    exit 1
fi

if [ "$PROFILE_TYPE" != "cpu" ] && [ "$PROFILE_TYPE" != "offcpu" ] && [ "$PROFILE_TYPE" != "mem" ]; then
    log_error "Invalid profile type: $PROFILE_TYPE"
    show_help
    exit 1
fi

if [ -n "$PID_ARG" ] && [ -n "$COMMAND_STRING" ]; then
    log_error "Options -p and -c are mutually exclusive"
    show_help
    exit 1
fi

if [ -z "$PID_ARG" ] && [ -z "$COMMAND_STRING" ]; then
    log_error "Either -p (PID) or -c (command) must be specified"
    show_help
    exit 1
fi

# Set defaults
if [ -z "$DURATION" ]; then
    DURATION=$DEFAULT_DURATION
fi

if [ -z "$FREQUENCY" ]; then
    FREQUENCY=$DEFAULT_FREQ
fi

# Validate PID if provided
if [ -n "$PID_ARG" ]; then
    if ! [[ "$PID_ARG" =~ ^[0-9]+$ ]]; then
        log_error "PID must be a number"
        exit 1
    fi
    if ! ps -p "$PID_ARG" > /dev/null 2>&1; then
        log_error "Process with PID $PID_ARG not found"
        exit 1
    fi
fi

# Check dependencies before doing any work
FLAMEGRAPH_PATH=$(check_dependencies "$FLAMEGRAPH_DIR")

# Main execution
echo ""
echo "========================================"
echo -e "${GREEN}Linux Perf Profiling Tool${NC}"
echo "========================================"
echo ""

# Determine target identifier
TARGET_TYPE=""
TARGET=""
IDENTIFIER=""
TITLE=""

if [ -n "$PID_ARG" ]; then
    TARGET_TYPE="pid"
    TARGET="$PID_ARG"
    IDENTIFIER="pid_${PID_ARG}"
    TITLE="PID: $PID_ARG"
    log_info "Target: Process PID $PID_ARG"
else
    TARGET_TYPE="cmd"
    TARGET="$COMMAND_STRING"
    CMD_BASE=$(echo "$COMMAND_STRING" | awk '{print $1}' | xargs basename)
    SANITIZED_CMD=$(echo "$CMD_BASE" | tr -cd '[:alnum:]_-')
    IDENTIFIER="cmd_${SANITIZED_CMD}"
    TITLE="Command: $CMD_BASE"
    log_info "Target: Command '$COMMAND_STRING'"
fi

log_info "Profile type: $PROFILE_TYPE"
log_info "Duration: ${DURATION}s"
if [ "$PROFILE_TYPE" == "cpu" ]; then
    log_info "Sampling frequency: ${FREQUENCY}Hz"
fi

setup_output_files "$PROFILE_TYPE" "$IDENTIFIER"

echo ""
echo "========================================"
echo "Starting profiling..."
echo "========================================"
echo ""

# Run appropriate profiling
case "$PROFILE_TYPE" in
    cpu)
        run_cpu_profiling "$TARGET_TYPE" "$TARGET" "$DURATION" "$FREQUENCY" || exit 1
        ;;
    offcpu)
        run_offcpu_profiling "$TARGET_TYPE" "$TARGET" "$DURATION" || exit 1
        ;;
    mem)
        run_mem_profiling "$TARGET_TYPE" "$TARGET" "$DURATION" || exit 1
        ;;
esac

echo ""
echo "========================================"
echo "Generating flame graph..."
echo "========================================"
echo ""

if ! generate_flamegraph "$FLAMEGRAPH_PATH" "$PROFILE_TYPE" "$TITLE"; then
    log_error "Flame graph generation failed"
    exit 1
fi

echo ""
echo "========================================"
log_info "Profiling completed successfully"
echo "========================================"
echo ""
log_info "Flame graph: $SVG_OUTPUT_FILE"
echo ""

# Offer to serve the flame graph
read -p "Do you want to start HTTP server to view the flame graph? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    serve_flamegraph "$SVG_OUTPUT_FILE"
else
    log_info "You can view the flame graph by opening: $SVG_OUTPUT_FILE"
fi

exit 0