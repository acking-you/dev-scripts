#!/bin/bash
# Run clang-tidy on changed lines in C++ files (with parallel support)
# Usage: ./tidy_changed_files.sh [base_branch] [jobs]
# Default base_branch: dev-v0.6
# Default jobs: number of CPU cores
# 
# This script performs line-level checking by using git diff to identify
# which lines were changed and only runs clang-tidy on those specific lines.

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if clang-tidy is installed
if ! command -v clang-tidy &> /dev/null; then
    echo -e "${RED}Error: clang-tidy is not installed${NC}"
    echo ""
    echo -e "${YELLOW}You can install it using:${NC}"
    echo -e "${BLUE}  # On macOS:${NC}"
    echo -e "${BLUE}  brew install llvm${NC}"
    echo -e "${BLUE}  # Then add to PATH: export PATH=\"/opt/homebrew/opt/llvm/bin:\$PATH\"${NC}"
    echo ""
    echo -e "${BLUE}  # On Ubuntu/Debian:${NC}"
    echo -e "${BLUE}  sudo apt-get install clang-tidy${NC}"
    echo ""
    echo -e "${BLUE}  # On CentOS/RHEL:${NC}"
    echo -e "${BLUE}  sudo yum install clang-tools-extra${NC}"
    echo ""
    echo -e "${BLUE}  # Or download from LLVM releases:${NC}"
    echo -e "${BLUE}  https://github.com/llvm/llvm-project/releases${NC}"
    exit 1
fi

# Get base branch from argument or use default
BASE_BRANCH="${1:-dev-v0.6}"

# Get number of parallel jobs (default to CPU cores)
if [ -n "$2" ]; then
    JOBS="$2"
elif command -v nproc &> /dev/null; then
    JOBS=$(nproc)
elif command -v sysctl &> /dev/null; then
    JOBS=$(sysctl -n hw.ncpu)
else
    JOBS=4
fi

echo -e "${YELLOW}Running clang-tidy on changed files compared to ${BASE_BRANCH}...${NC}"
echo -e "${YELLOW}Using ${JOBS} parallel jobs${NC}"

# Check if base branch exists
if ! git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
    echo -e "${RED}Error: Base branch '$BASE_BRANCH' does not exist${NC}"
    exit 1
fi

# Get list of changed files
CHANGED_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD; git diff --name-only)

# Filter for C++ source files only (.cc, .cpp) - exclude headers
CPP_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(cc|cpp)$' | sort -u || true)

if [ -z "$CPP_FILES" ]; then
    echo -e "${GREEN}No C++ source files changed. Nothing to check.${NC}"
    exit 0
fi

echo -e "${YELLOW}Found changed C++ source files:${NC}"
echo "$CPP_FILES" | while read -r file; do
    if [ -f "$file" ]; then
        echo "  - $file"
    fi
done

# Count files
FILE_COUNT=$(echo "$CPP_FILES" | wc -l | tr -d ' ')
echo -e "${YELLOW}Total: $FILE_COUNT file(s)${NC}"

# Check if compile_commands.json exists
if [ ! -f "compile_commands.json" ]; then
    echo -e "${RED}Warning: compile_commands.json not found in current directory${NC}"
    echo -e "${YELLOW}You may need to generate it first with:${NC}"
    echo -e "${BLUE}  cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build${NC}"
    echo -e "${BLUE}  ln -s build/compile_commands.json .${NC}"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create temp directory for outputs
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo -e "${YELLOW}Running clang-tidy in parallel...${NC}"
echo ""

# Function to generate line filter for git diff
generate_line_filter() {
    local file="$1"
    local base_branch="$2"
    local line_filter_json
    
    # Get git diff output in a format we can parse
    # We need to find which lines were added or modified
    local diff_output
    diff_output=$(git diff "$base_branch"...HEAD --unified=0 "$file" 2>/dev/null || echo "")
    
    # Also include unstaged changes
    local unstaged_diff
    unstaged_diff=$(git diff --unified=0 "$file" 2>/dev/null || echo "")
    
    # Combine both diffs
    if [ -n "$unstaged_diff" ]; then
        if [ -n "$diff_output" ]; then
            diff_output="${diff_output}"$'\n'"${unstaged_diff}"
        else
            diff_output="$unstaged_diff"
        fi
    fi
    
    if [ -z "$diff_output" ]; then
        return 1
    fi
    
    # Parse diff to get line numbers
    # Format: @@ -start,count +start,count @@
    local lines=()
    while IFS= read -r line; do
        # Only process lines that start with @@
        if [[ "$line" =~ ^@@\ -[0-9]+(,[0-9]+)?\ \+([0-9]+)(,([0-9]+))?\ @@.* ]]; then
            local start_line="${BASH_REMATCH[2]}"
            local line_count="${BASH_REMATCH[4]}"
            
            # Skip if line_count is 0 (pure deletion)
            if [ "$line_count" = "0" ]; then
                continue
            fi
            
            # Default to 1 if count is not specified
            if [ -z "$line_count" ]; then
                line_count=1
            fi
            
            # clang-tidy uses 1-based line numbers
            local end_line=$((start_line + line_count - 1))
            
            lines+=("$start_line,$end_line")
        fi
    done <<< "$diff_output"
    
    if [ ${#lines[@]} -eq 0 ]; then
        return 1
    fi
    
    # Create JSON line filter for clang-tidy
    # Format: [{"name":"file.c","lines":[[0,5],[10,15]]}]
    local joined_lines
    joined_lines=$(printf '[%s],' "${lines[@]}" | sed 's/,$//')
    
    line_filter_json="[{\"name\":\"$file\",\"lines\":[$joined_lines]}]"
    echo "$line_filter_json"
    return 0
}

# Function to check a single file with line-level filtering
check_file() {
    local file="$1"
    local temp_dir="$2"
    local base_branch="$3"
    local output_file="${temp_dir}/$(echo "$file" | sed 's/\//_/g').txt"
    
    if [ ! -f "$file" ]; then
        echo "SKIPPED" > "$output_file"
        return
    fi
    
    # Generate line filter for this file
    local line_filter
    line_filter=$(generate_line_filter "$file" "$base_branch")
    
    if [ $? -ne 0 ] || [ -z "$line_filter" ]; then
        echo "SKIPPED (no changed lines)" > "$output_file"
        return
    fi
    
    # Run clang-tidy with line filter and capture output
    echo -e "${BLUE}Running:${NC} clang-tidy \"$file\" --line-filter=\"$line_filter\"" >&2
    if OUTPUT=$(clang-tidy "$file" --line-filter="$line_filter" 2>&1); then
        if echo "$OUTPUT" | grep -q "warning:\|error:"; then
            if echo "$OUTPUT" | grep -q "error:"; then
                echo "ERROR" > "$output_file"
            else
                echo "WARNING" > "$output_file"
            fi
            echo "$OUTPUT" >> "$output_file"
        else
            echo "OK" > "$output_file"
        fi
    else
        echo "FAILED" > "$output_file"
        echo "$OUTPUT" >> "$output_file"
    fi
}

export -f check_file
export -f generate_line_filter
export TEMP_DIR
export BASE_BRANCH
export RED
export GREEN
export YELLOW
export BLUE
export NC

# Choose parallel execution method
if command -v parallel &> /dev/null; then
    # Use GNU parallel (best option)
    echo "$CPP_FILES" | parallel -j "$JOBS" check_file {} "$TEMP_DIR" "$BASE_BRANCH"
elif command -v xargs &> /dev/null; then
    # Use xargs -P (good fallback)
    echo "$CPP_FILES" | xargs -P "$JOBS" -I {} bash -c "check_file '{}' '$TEMP_DIR' '$BASE_BRANCH'"
else
    # Fallback to sequential processing
    echo -e "${YELLOW}Neither 'parallel' nor 'xargs' found, running sequentially...${NC}"
    mapfile -t FILES_ARRAY <<< "$CPP_FILES"
    for file in "${FILES_ARRAY[@]}"; do
        [ -n "$file" ] && check_file "$file" "$TEMP_DIR" "$BASE_BRANCH"
    done
fi

# Collect results
CHECKED_COUNT=0
ERROR_COUNT=0
WARNING_COUNT=0

mapfile -t FILES_ARRAY <<< "$CPP_FILES"
for file in "${FILES_ARRAY[@]}"; do
    [ -z "$file" ] && continue
    
    output_file="${TEMP_DIR}/$(echo "$file" | sed 's/\//_/g').txt"
    
    if [ ! -f "$output_file" ]; then
        continue
    fi
    
    status=$(head -n 1 "$output_file")
    
    case "$status" in
        OK)
            echo -e "${GREEN}✓${NC} $file: No issues found"
            CHECKED_COUNT=$((CHECKED_COUNT + 1))
            ;;
        WARNING)
            echo -e "${YELLOW}⚠${NC} $file: Found warnings"
            tail -n +2 "$output_file"
            WARNING_COUNT=$((WARNING_COUNT + 1))
            CHECKED_COUNT=$((CHECKED_COUNT + 1))
            ;;
        ERROR)
            echo -e "${RED}✗${NC} $file: Found errors"
            tail -n +2 "$output_file"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            CHECKED_COUNT=$((CHECKED_COUNT + 1))
            ;;
        FAILED)
            echo -e "${RED}✗${NC} $file: clang-tidy failed"
            tail -n +2 "$output_file"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            CHECKED_COUNT=$((CHECKED_COUNT + 1))
            ;;
        SKIPPED*)
            if [[ "$status" == *"no changed lines"* ]]; then
                echo -e "${BLUE}-${NC} $file: Skipped (no changed lines)"
            else
                echo -e "${YELLOW}⚠${NC} $file: Skipped (file not found)"
            fi
            ;;
    esac
done

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Summary:${NC}"
echo -e "  Checked: $CHECKED_COUNT file(s)"
echo -e "  ${RED}Errors: $ERROR_COUNT${NC}"
echo -e "  ${YELLOW}Warnings: $WARNING_COUNT${NC}"

if [ $ERROR_COUNT -gt 0 ]; then
    echo -e "${RED}clang-tidy check failed with errors!${NC}"
    exit 1
elif [ $WARNING_COUNT -gt 0 ]; then
    echo -e "${YELLOW}clang-tidy check completed with warnings.${NC}"
    exit 0
else
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
fi