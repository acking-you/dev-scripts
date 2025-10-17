#!/bin/bash
# Format changed C++ files using clang-format (line-level formatting)
# Usage: ./format_changed_files.sh [base_branch]
# Default base_branch: dev-v0.6
# 
# This script performs line-level formatting by using git diff to identify
# which lines were changed and only formats those specific lines.

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if clang-format is installed
if ! command -v clang-format &> /dev/null; then
    echo -e "${RED}Error: clang-format is not installed${NC}"
    echo ""
    echo -e "${YELLOW}You can install it using:${NC}"
    echo -e "${BLUE}  # On macOS:${NC}"
    echo -e "${BLUE}  brew install clang-format${NC}"
    echo ""
    echo -e "${BLUE}  # On Ubuntu/Debian:${NC}"
    echo -e "${BLUE}  sudo apt-get install clang-format${NC}"
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

# Function to generate line ranges for git diff
generate_line_ranges() {
    local file="$1"
    local base_branch="$2"
    
    # Get git diff output in a format we can parse
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
            
            # clang-format uses 1-based line numbers
            local end_line=$((start_line + line_count - 1))
            
            lines+=("--lines=$start_line:$end_line")
        fi
    done <<< "$diff_output"
    
    if [ ${#lines[@]} -eq 0 ]; then
        return 1
    fi
    
    # Return space-separated line range arguments
    echo "${lines[@]}"
    return 0
}

echo -e "${YELLOW}Formatting changed files compared to ${BASE_BRANCH}...${NC}"

# Check if base branch exists
if ! git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
    echo -e "${RED}Error: Base branch '$BASE_BRANCH' does not exist${NC}"
    exit 1
fi

# Get list of changed files
# 1. Files changed compared to base branch (committed changes)
# 2. Files with uncommitted changes (staged and unstaged)
CHANGED_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD; git diff --name-only)

# Filter for C++ files only (.cc, .h, .cpp, .hpp)
CPP_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(cc|h|cpp|hpp)$' | sort -u || true)

if [ -z "$CPP_FILES" ]; then
    echo -e "${GREEN}No C++ files changed. Nothing to format.${NC}"
    exit 0
fi

echo -e "${YELLOW}Found changed C++ files:${NC}"
echo "$CPP_FILES" | while read -r file; do
    if [ -f "$file" ]; then
        echo "  - $file"
    fi
done

# Count files
FILE_COUNT=$(echo "$CPP_FILES" | wc -l | tr -d ' ')
echo -e "${YELLOW}Total: $FILE_COUNT file(s)${NC}"

# Format the files
echo -e "${YELLOW}Running clang-format on changed lines...${NC}"
FORMATTED_COUNT=0
SKIPPED_COUNT=0

while IFS= read -r file; do
    [ -z "$file" ] && continue
    
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠${NC} Skipped (file not found): $file"
        ((SKIPPED_COUNT++))
        continue
    fi
    
    # Generate line ranges for this file
    line_ranges=$(generate_line_ranges "$file" "$BASE_BRANCH")
    
    if [ $? -ne 0 ] || [ -z "$line_ranges" ]; then
        echo -e "${BLUE}-${NC} Skipped (no changed lines): $file"
        ((SKIPPED_COUNT++))
        continue
    fi
    
    # Format only the changed lines
    echo -e "${BLUE}Formatting:${NC} clang-format -i $line_ranges \"$file\""
    if clang-format -i $line_ranges "$file"; then
        echo -e "${GREEN}✓${NC} Formatted: $file"
        ((FORMATTED_COUNT++))
    else
        echo -e "${RED}✗${NC} Failed to format: $file"
    fi
done <<< "$CPP_FILES"

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Summary:${NC}"
echo -e "  Formatted: $FORMATTED_COUNT file(s)"
echo -e "  Skipped: $SKIPPED_COUNT file(s)"
echo -e "${GREEN}Formatting complete!${NC}"

# Show git status if there are changes
if ! git diff --quiet; then
    echo ""
    echo -e "${YELLOW}Files modified by clang-format:${NC}"
    git diff --name-only | grep -E '\.(cc|h|cpp|hpp)$' || true
fi