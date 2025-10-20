#!/bin/bash

################################################################################
# Valgrind Diagnostic Tool Script
# Purpose: Quick diagnostic tool for memory leaks, deadlocks, performance 
#          issues, and segmentation faults using Valgrind
# Version: 1.0
################################################################################

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
OUTPUT_DIR="./valgrind_reports"
TOOL="memcheck"
LEAK_CHECK="full"
TRACK_ORIGINS="yes"
NUM_CALLERS=30
VERBOSE=0
ATTACH_PID=""
PROGRAM=""
PROGRAM_ARGS=""

################################################################################
# Help Information
################################################################################
function show_help() {
    echo -e "${GREEN}Valgrind Diagnostic Tool${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "    $0 [options] <program> [program_args...]"
    echo ""
    echo -e "${YELLOW}Diagnostic Modes:${NC}"
    echo -e "    ${BLUE}-m, --memcheck${NC}        Memory leak detection (default)"
    echo -e "    ${BLUE}-t, --threadcheck${NC}     Deadlock and data race detection (Helgrind)"
    echo -e "    ${BLUE}-c, --callgrind${NC}       Performance profiling (Callgrind)"
    echo -e "    ${BLUE}-g, --cachegrind${NC}      Cache performance analysis (Cachegrind)"
    echo -e "    ${BLUE}-M, --massif${NC}          Heap memory profiling (Massif)"
    echo -e "    ${BLUE}-a, --all${NC}             Run all diagnostics (except Callgrind)"
    echo ""
    echo -e "${YELLOW}General Options:${NC}"
    echo -e "    ${BLUE}-o, --output DIR${NC}      Output directory (default: $OUTPUT_DIR)"
    echo -e "    ${BLUE}-p, --pid PID${NC}         Attach to running process (experimental)"
    echo -e "    ${BLUE}-v, --verbose${NC}         Verbose output"
    echo -e "    ${BLUE}-h, --help${NC}            Show this help message"
    echo ""
    echo -e "${YELLOW}Memcheck Specific Options:${NC}"
    echo -e "    ${BLUE}--leak-check LEVEL${NC}    Leak check level: summary|full (default: full)"
    echo -e "    ${BLUE}--track-origins yes|no${NC} Track origins of uninitialized values (default: yes)"
    echo -e "    ${BLUE}--show-reachable${NC}       Show reachable memory blocks"
    echo -e "    ${BLUE}--undef-value-errors no${NC} Disable uninitialized value errors"
    echo ""
    echo -e "${YELLOW}Helgrind Specific Options:${NC}"
    echo -e "    ${BLUE}--history-level LEVEL${NC}  Access history level: none|approx|full (default: full)"
    echo -e "    ${BLUE}--conflict-cache-size N${NC} Conflict cache size (default: 10000000)"
    echo ""
    echo -e "${YELLOW}Callgrind Specific Options:${NC}"
    echo -e "    ${BLUE}--dump-instr yes|no${NC}    Record instruction-level profiling (default: no)"
    echo -e "    ${BLUE}--cache-sim yes|no${NC}     Simulate cache (default: yes)"
    echo -e "    ${BLUE}--branch-sim yes|no${NC}    Simulate branch prediction (default: no)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "    # Memory leak detection"
    echo "    $0 -m ./my_program arg1 arg2"
    echo ""
    echo "    # Deadlock detection"
    echo "    $0 -t ./my_program"
    echo ""
    echo "    # Performance profiling with visualization"
    echo "    $0 -c ./my_program"
    echo ""
    echo "    # Run all diagnostics"
    echo "    $0 -a ./my_program"
    echo ""
    echo "    # Attach to running process (requires root)"
    echo "    sudo $0 -m -p 12345"
    echo ""
    echo "    # Custom output directory with verbose output"
    echo "    $0 -m -o /tmp/reports -v ./my_program"
    echo ""
    echo -e "${YELLOW}Output Files:${NC}"
    echo "    Reports are saved in the output directory with format:"
    echo "    - memcheck_<timestamp>.log          Memory check report"
    echo "    - helgrind_<timestamp>.log          Deadlock detection report"
    echo "    - callgrind.out.<timestamp>         Callgrind data file"
    echo "    - cachegrind.out.<timestamp>        Cachegrind data file"
    echo "    - massif.out.<timestamp>            Massif heap profiling file"
    echo ""
    echo -e "${YELLOW}Analysis Tools:${NC}"
    echo "    - kcachegrind: Visualize Callgrind/Cachegrind output"
    echo "    - massif-visualizer: Visualize Massif output"
    echo "    - Use 'ms_print massif.out.<pid>' to view Massif text report"
    echo ""
    echo -e "${YELLOW}Important Notes:${NC}"
    echo "    1. Valgrind significantly slows down program execution (10-100x)"
    echo "    2. Ensure program is compiled with debug symbols (-g)"
    echo "    3. Helgrind may produce false positives, especially for lock-free structures"
    echo "    4. Callgrind analysis of large programs may generate huge output files"
    echo ""
}

################################################################################
# Logging Functions
################################################################################
function log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function log_debug() {
    if [ $VERBOSE -eq 1 ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

################################################################################
# Check Dependencies
################################################################################
function check_dependencies() {
    log_debug "Checking dependencies..."
    
    if ! command -v valgrind &> /dev/null; then
        log_error "Valgrind not installed"
        echo "Please install Valgrind:"
        echo "  Ubuntu/Debian: sudo apt-get install valgrind"
        echo "  CentOS/RHEL:   sudo yum install valgrind"
        echo "  macOS:         brew install valgrind"
        exit 1
    fi
    
    VALGRIND_VERSION=$(valgrind --version | grep -oP '\d+\.\d+\.\d+')
    log_info "Valgrind version: $VALGRIND_VERSION"
}

################################################################################
# Setup Output Directory
################################################################################
function setup_output_dir() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        log_info "Created output directory: $OUTPUT_DIR"
    else
        log_debug "Output directory exists: $OUTPUT_DIR"
    fi
}

################################################################################
# Generate Timestamp
################################################################################
function get_timestamp() {
    date +%Y%m%d_%H%M%S
}

################################################################################
# Memory Leak Detection (Memcheck)
################################################################################
function run_memcheck() {
    local timestamp=$(get_timestamp)
    local log_file="$OUTPUT_DIR/memcheck_${timestamp}.log"
    local suppressions=""
    
    log_info "Running Memcheck (memory leak detection)..."
    log_info "Output file: $log_file"
    
    # Check for suppression file
    if [ -f "valgrind.supp" ]; then
        suppressions="--suppressions=valgrind.supp"
        log_debug "Using suppression file: valgrind.supp"
    fi
    
    # Build Valgrind command
    local cmd="valgrind"
    cmd="$cmd --tool=memcheck"
    cmd="$cmd --leak-check=$LEAK_CHECK"
    cmd="$cmd --show-leak-kinds=all"
    cmd="$cmd --track-origins=$TRACK_ORIGINS"
    cmd="$cmd --verbose"
    cmd="$cmd --log-file=$log_file"
    cmd="$cmd --num-callers=$NUM_CALLERS"
    cmd="$cmd --trace-children=yes"
    cmd="$cmd --leak-resolution=high"
    
    # Add extra Memcheck options
    if [ ! -z "$MEMCHECK_OPTS" ]; then
        cmd="$cmd $MEMCHECK_OPTS"
    fi
    
    if [ ! -z "$suppressions" ]; then
        cmd="$cmd $suppressions"
    fi
    
    # Run program
    if [ ! -z "$ATTACH_PID" ]; then
        log_error "Memcheck does not support attaching to running processes"
        return 1
    fi
    
    log_debug "Executing: $cmd $PROGRAM $PROGRAM_ARGS"
    
    $cmd $PROGRAM $PROGRAM_ARGS
    local exit_code=$?
    
    # Analyze results
    log_info "Memcheck completed (exit code: $exit_code)"
    analyze_memcheck_report "$log_file"
}

################################################################################
# Analyze Memcheck Report
################################################################################
function analyze_memcheck_report() {
    local log_file="$1"
    
    if [ ! -f "$log_file" ]; then
        log_error "Report file not found: $log_file"
        return
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Memcheck Summary${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Extract leak summary
    if grep -q "LEAK SUMMARY" "$log_file"; then
        echo -e "\n${YELLOW}Memory Leak Summary:${NC}"
        grep -A 5 "LEAK SUMMARY" "$log_file" | tail -5
    fi
    
    # Count error types
    local invalid_read=$(grep -c "Invalid read" "$log_file" || true)
    local invalid_write=$(grep -c "Invalid write" "$log_file" || true)
    local uninit_value=$(grep -c "Conditional jump or move depends on uninitialised value" "$log_file" || true)
    local invalid_free=$(grep -c "Invalid free" "$log_file" || true)
    
    echo -e "\n${YELLOW}Error Statistics:${NC}"
    echo "  Invalid reads:         $invalid_read"
    echo "  Invalid writes:        $invalid_write"
    echo "  Uninitialized values:  $uninit_value"
    echo "  Invalid frees:         $invalid_free"
    
    # Extract first 5 errors
    echo -e "\n${YELLOW}First 5 Error Locations:${NC}"
    grep -E "^==[0-9]+== (at|by) 0x" "$log_file" | head -10
    
    echo -e "\n${BLUE}Full report: $log_file${NC}"
    echo -e "${GREEN}========================================${NC}\n"
}

################################################################################
# Deadlock and Thread Error Detection (Helgrind)
################################################################################
function run_helgrind() {
    local timestamp=$(get_timestamp)
    local log_file="$OUTPUT_DIR/helgrind_${timestamp}.log"
    
    log_info "Running Helgrind (deadlock and data race detection)..."
    log_info "Output file: $log_file"
    
    # Build Valgrind command
    local cmd="valgrind"
    cmd="$cmd --tool=helgrind"
    cmd="$cmd --log-file=$log_file"
    cmd="$cmd --num-callers=$NUM_CALLERS"
    cmd="$cmd --read-var-info=yes"
    cmd="$cmd --history-level=${HELGRIND_HISTORY:-full}"
    cmd="$cmd --conflict-cache-size=${HELGRIND_CACHE_SIZE:-10000000}"
    cmd="$cmd --free-is-write=yes"
    
    # Add suppressions
    if [ -f "helgrind.supp" ]; then
        cmd="$cmd --suppressions=helgrind.supp"
        log_debug "Using suppression file: helgrind.supp"
    fi
    
    log_debug "Executing: $cmd $PROGRAM $PROGRAM_ARGS"
    
    $cmd $PROGRAM $PROGRAM_ARGS
    local exit_code=$?
    
    log_info "Helgrind completed (exit code: $exit_code)"
    analyze_helgrind_report "$log_file"
}

################################################################################
# Analyze Helgrind Report
################################################################################
function analyze_helgrind_report() {
    local log_file="$1"
    
    if [ ! -f "$log_file" ]; then
        log_error "Report file not found: $log_file"
        return
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Helgrind Summary${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Count issue types
    local lock_order=$(grep -c "lock order.*violated" "$log_file" || true)
    local data_race=$(grep -c "Possible data race" "$log_file" || true)
    local locked_mutex=$(grep -c "pthread_mutex_destroy of a locked mutex" "$log_file" || true)
    
    echo -e "\n${YELLOW}Issue Statistics:${NC}"
    echo "  Lock order violations:     $lock_order"
    echo "  Data races:                $data_race"
    echo "  Destroy locked mutex:      $locked_mutex"
    
    # Extract lock order issues
    if [ $lock_order -gt 0 ]; then
        echo -e "\n${YELLOW}Lock Order Violation Example:${NC}"
        grep -A 10 "lock order.*violated" "$log_file" | head -20
    fi
    
    # Extract data races
    if [ $data_race -gt 0 ]; then
        echo -e "\n${YELLOW}Data Race Example:${NC}"
        grep -A 10 "Possible data race" "$log_file" | head -20
    fi
    
    echo -e "\n${BLUE}Full report: $log_file${NC}"
    
    # Group issues by file
    echo -e "\n${YELLOW}Issues Grouped by File:${NC}"
    grep -oP '\S+\.cc:\d+' "$log_file" | sort | uniq -c | sort -rn | head -10
    
    echo -e "${GREEN}========================================${NC}\n"
}

################################################################################
# Performance Profiling (Callgrind)
################################################################################
function run_callgrind() {
    local timestamp=$(get_timestamp)
    local out_file="$OUTPUT_DIR/callgrind.out.${timestamp}"
    
    log_info "Running Callgrind (performance profiling)..."
    log_info "Output file: $out_file"
    
    # Build Valgrind command
    local cmd="valgrind"
    cmd="$cmd --tool=callgrind"
    cmd="$cmd --callgrind-out-file=$out_file"
    cmd="$cmd --dump-instr=${CALLGRIND_INSTR:-no}"
    cmd="$cmd --cache-sim=${CALLGRIND_CACHE:-yes}"
    cmd="$cmd --branch-sim=${CALLGRIND_BRANCH:-no}"
    cmd="$cmd --collect-jumps=yes"
    
    log_debug "Executing: $cmd $PROGRAM $PROGRAM_ARGS"
    
    $cmd $PROGRAM $PROGRAM_ARGS
    local exit_code=$?
    
    log_info "Callgrind completed (exit code: $exit_code)"
    analyze_callgrind_output "$out_file"
}

################################################################################
# Analyze Callgrind Output
################################################################################
function analyze_callgrind_output() {
    local out_file="$1"
    
    if [ ! -f "$out_file" ]; then
        log_error "Output file not found: $out_file"
        return
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Callgrind Summary${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Check if callgrind_annotate is available
    if command -v callgrind_annotate &> /dev/null; then
        echo -e "\n${YELLOW}CPU Hotspot Functions (top 20):${NC}"
        callgrind_annotate "$out_file" | head -50
        
        # Generate text report
        local report_file="${out_file}.txt"
        callgrind_annotate "$out_file" > "$report_file"
        log_info "Text report: $report_file"
    else
        log_warn "callgrind_annotate not found, cannot generate summary"
    fi
    
    echo -e "\n${BLUE}Callgrind data file: $out_file${NC}"
    
    # Check if kcachegrind is available
    if command -v kcachegrind &> /dev/null; then
        echo -e "${YELLOW}Visualization:${NC}"
        echo "  Run: kcachegrind $out_file"
    else
        log_warn "kcachegrind not installed, cannot visualize"
        echo "  Install: sudo apt-get install kcachegrind  (Ubuntu/Debian)"
    fi
    
    echo -e "${GREEN}========================================${NC}\n"
}

################################################################################
# Cache Performance Analysis (Cachegrind)
################################################################################
function run_cachegrind() {
    local timestamp=$(get_timestamp)
    local out_file="$OUTPUT_DIR/cachegrind.out.${timestamp}"
    
    log_info "Running Cachegrind (cache performance analysis)..."
    log_info "Output file: $out_file"
    
    # Build Valgrind command
    local cmd="valgrind"
    cmd="$cmd --tool=cachegrind"
    cmd="$cmd --cachegrind-out-file=$out_file"
    cmd="$cmd --branch-sim=yes"
    
    log_debug "Executing: $cmd $PROGRAM $PROGRAM_ARGS"
    
    $cmd $PROGRAM $PROGRAM_ARGS
    local exit_code=$?
    
    log_info "Cachegrind completed (exit code: $exit_code)"
    analyze_cachegrind_output "$out_file"
}

################################################################################
# Analyze Cachegrind Output
################################################################################
function analyze_cachegrind_output() {
    local out_file="$1"
    
    if [ ! -f "$out_file" ]; then
        log_error "Output file not found: $out_file"
        return
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Cachegrind Summary${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Check if cg_annotate is available
    if command -v cg_annotate &> /dev/null; then
        echo -e "\n${YELLOW}Cache Statistics:${NC}"
        cg_annotate "$out_file" | head -40
        
        # Generate text report
        local report_file="${out_file}.txt"
        cg_annotate "$out_file" > "$report_file"
        log_info "Text report: $report_file"
    else
        log_warn "cg_annotate not found, cannot generate summary"
    fi
    
    echo -e "\n${BLUE}Cachegrind data file: $out_file${NC}"
    echo -e "${GREEN}========================================${NC}\n"
}

################################################################################
# Heap Memory Profiling (Massif)
################################################################################
function run_massif() {
    local timestamp=$(get_timestamp)
    local out_file="$OUTPUT_DIR/massif.out.${timestamp}"
    
    log_info "Running Massif (heap memory profiling)..."
    log_info "Output file: $out_file"
    
    # Build Valgrind command
    local cmd="valgrind"
    cmd="$cmd --tool=massif"
    cmd="$cmd --massif-out-file=$out_file"
    cmd="$cmd --time-unit=B"
    cmd="$cmd --detailed-freq=1"
    cmd="$cmd --max-snapshots=100"
    cmd="$cmd --threshold=0.1"
    
    log_debug "Executing: $cmd $PROGRAM $PROGRAM_ARGS"
    
    $cmd $PROGRAM $PROGRAM_ARGS
    local exit_code=$?
    
    log_info "Massif completed (exit code: $exit_code)"
    analyze_massif_output "$out_file"
}

################################################################################
# Analyze Massif Output
################################################################################
function analyze_massif_output() {
    local out_file="$1"
    
    if [ ! -f "$out_file" ]; then
        log_error "Output file not found: $out_file"
        return
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Massif Summary${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Check if ms_print is available
    if command -v ms_print &> /dev/null; then
        echo -e "\n${YELLOW}Heap Memory Usage Trend:${NC}"
        ms_print "$out_file" | head -80
        
        # Generate text report
        local report_file="${out_file}.txt"
        ms_print "$out_file" > "$report_file"
        log_info "Text report: $report_file"
    else
        log_warn "ms_print not found, cannot generate summary"
    fi
    
    echo -e "\n${BLUE}Massif data file: $out_file${NC}"
    
    # Check if massif-visualizer is available
    if command -v massif-visualizer &> /dev/null; then
        echo -e "${YELLOW}Visualization:${NC}"
        echo "  Run: massif-visualizer $out_file"
    else
        log_warn "massif-visualizer not installed, cannot visualize"
    fi
    
    echo -e "${GREEN}========================================${NC}\n"
}

################################################################################
# Run All Diagnostics
################################################################################
function run_all() {
    log_info "Running all diagnostics..."
    echo ""
    
    run_memcheck
    echo -e "\n${BLUE}========================================${NC}\n"
    
    run_helgrind
    echo -e "\n${BLUE}========================================${NC}\n"
    
    run_cachegrind
    echo -e "\n${BLUE}========================================${NC}\n"
    
    run_massif
    
    log_info "All diagnostics completed!"
    log_info "Reports directory: $OUTPUT_DIR"
}

################################################################################
# Generate Suppression File Template
################################################################################
function generate_suppression_template() {
    local supp_file="$OUTPUT_DIR/valgrind_template.supp"
    
    cat > "$supp_file" << 'EOF'
# Valgrind Suppression File Template
# Use this to filter known false positives

{
   ignore_std_string_false_positive
   Memcheck:Leak
   fun:*std::__cxx11::basic_string*
}

{
   ignore_glibc_dl_init
   Helgrind:Race
   fun:*dl_init*
}

{
   ignore_pthread_create_race
   Helgrind:Race
   fun:pthread_create*
}

# Add custom suppressions:
# 1. Run valgrind with --gen-suppressions=all
# 2. Copy suppression blocks from output to this file
# 3. Add comments to describe purpose

EOF
    
    log_info "Suppression template generated: $supp_file"
}

################################################################################
# Main Function
################################################################################
function main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--memcheck)
                TOOL="memcheck"
                shift
                ;;
            -t|--threadcheck)
                TOOL="helgrind"
                shift
                ;;
            -c|--callgrind)
                TOOL="callgrind"
                shift
                ;;
            -g|--cachegrind)
                TOOL="cachegrind"
                shift
                ;;
            -M|--massif)
                TOOL="massif"
                shift
                ;;
            -a|--all)
                TOOL="all"
                shift
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -p|--pid)
                ATTACH_PID="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            --leak-check)
                LEAK_CHECK="$2"
                shift 2
                ;;
            --track-origins)
                TRACK_ORIGINS="$2"
                shift 2
                ;;
            --show-reachable)
                MEMCHECK_OPTS="$MEMCHECK_OPTS --show-reachable=yes"
                shift
                ;;
            --undef-value-errors)
                MEMCHECK_OPTS="$MEMCHECK_OPTS --undef-value-errors=$2"
                shift 2
                ;;
            --history-level)
                HELGRIND_HISTORY="$2"
                shift 2
                ;;
            --conflict-cache-size)
                HELGRIND_CACHE_SIZE="$2"
                shift 2
                ;;
            --dump-instr)
                CALLGRIND_INSTR="$2"
                shift 2
                ;;
            --cache-sim)
                CALLGRIND_CACHE="$2"
                shift 2
                ;;
            --branch-sim)
                CALLGRIND_BRANCH="$2"
                shift 2
                ;;
            --gen-suppressions)
                generate_suppression_template
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                # First non-option argument is program name
                if [ -z "$PROGRAM" ]; then
                    PROGRAM="$1"
                else
                    PROGRAM_ARGS="$PROGRAM_ARGS $1"
                fi
                shift
                ;;
        esac
    done
    
    # Check if program or PID specified
    if [ -z "$PROGRAM" ] && [ -z "$ATTACH_PID" ]; then
        log_error "No program or process ID specified"
        echo ""
        show_help
        exit 1
    fi
    
    # Check if program exists
    if [ ! -z "$PROGRAM" ] && [ ! -f "$PROGRAM" ] && [ ! -x "$(command -v $PROGRAM)" ]; then
        log_error "Program does not exist or is not executable: $PROGRAM"
        exit 1
    fi
    
    # Check dependencies
    check_dependencies
    
    # Setup output directory
    setup_output_dir
    
    # Run appropriate diagnostic
    case $TOOL in
        memcheck)
            run_memcheck
            ;;
        helgrind)
            run_helgrind
            ;;
        callgrind)
            run_callgrind
            ;;
        cachegrind)
            run_cachegrind
            ;;
        massif)
            run_massif
            ;;
        all)
            run_all
            ;;
        *)
            log_error "Unknown tool: $TOOL"
            exit 1
            ;;
    esac
    
    echo ""
    log_info "Diagnostic completed! All reports saved in: $OUTPUT_DIR"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Review the generated report files"
    echo "  2. Use visualization tools (kcachegrind/massif-visualizer)"
    echo "  3. Fix issues found in reports"
    echo "  4. Generate suppression file: $0 --gen-suppressions"
    echo ""
}

# Run main function
main "$@"