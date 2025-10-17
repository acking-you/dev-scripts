# Clang Tools Guide

Scripts for formatting and checking C++ code using clang-format and clang-tidy, with intelligent line-level filtering based on git changes.

## Table of Contents

- [format_changed_files.sh](#format_changed_filessh)
- [tidy_changed_files.sh](#tidy_changed_filessh)
- [Common Features](#common-features)
- [Prerequisites](#prerequisites)
- [Usage Examples](#usage-examples)

---

## format_changed_files.sh

A script that formats only the changed lines in C++ files using clang-format, based on git diff analysis.

### Features

- **Line-level formatting**: Only formats lines that were actually modified
- **Git-aware**: Compares against a base branch to identify changes
- **Comprehensive coverage**: Includes both committed and uncommitted changes
- **Smart file detection**: Automatically finds C++ files (.cc, .h, .cpp, .hpp)
- **Detailed output**: Color-coded progress and summary reporting
- **Safe operation**: Only modifies lines you've changed

### Usage

```bash
./format_changed_files.sh [base_branch]
```

**Parameters:**
- `base_branch` (optional): The branch to compare against. Default: `dev-v0.6`

### How It Works

1. **Change Detection**: Identifies all C++ files modified compared to base branch
2. **Line Analysis**: Uses `git diff` to determine exactly which lines changed
3. **Targeted Formatting**: Runs `clang-format` with `--lines=start:end` for each changed region
4. **Reports Results**: Shows which files were formatted and which were skipped

### Output

The script provides:
- List of changed C++ files found
- Progress indicator for each file
- Summary: formatted count, skipped count
- Git diff output showing modified files

**Exit Codes:**
- `0`: Success
- `1`: clang-format not installed or base branch doesn't exist

### Example

```bash
# Format changes compared to main branch
./format_changed_files.sh main

# Format changes compared to default branch (dev-v0.6)
./format_changed_files.sh
```

**Output Example:**
```
Formatting changed files compared to main...
Found changed C++ files:
  - src/example.cpp
  - src/example.h
Total: 2 file(s)
Running clang-format on changed lines...
Formatting: clang-format -i --lines=10:15 --lines=20:25 "src/example.cpp"
✓ Formatted: src/example.cpp
- Skipped (no changed lines): src/example.h

========================================
Summary:
  Formatted: 1 file(s)
  Skipped: 1 file(s)
Formatting complete!
```

---

## tidy_changed_files.sh

A script that runs clang-tidy static analysis only on changed lines in C++ source files, with parallel execution support.

### Features

- **Line-level checking**: Only analyzes lines that were actually modified
- **Parallel execution**: Uses GNU parallel or xargs for faster processing
- **Git-aware**: Compares against a base branch to identify changes
- **Comprehensive coverage**: Includes both committed and uncommitted changes
- **Compile commands aware**: Uses compile_commands.json for accurate analysis
- **Smart file detection**: Focuses on C++ source files (.cc, .cpp) - headers are checked transitively
- **Detailed reporting**: Categorizes issues as errors or warnings with full output

### Usage

```bash
./tidy_changed_files.sh [base_branch] [jobs]
```

**Parameters:**
- `base_branch` (optional): The branch to compare against. Default: `dev-v0.6`
- `jobs` (optional): Number of parallel jobs. Default: number of CPU cores

### Prerequisites

This script requires `compile_commands.json` for accurate analysis. Generate it with:

```bash
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
ln -s build/compile_commands.json .
```

### How It Works

1. **Change Detection**: Identifies all C++ source files modified compared to base branch
2. **Line Analysis**: Uses `git diff` to determine exactly which lines changed
3. **Line Filter Generation**: Creates JSON line filter for clang-tidy (e.g., `[{"name":"file.cpp","lines":[[10,15],[20,25]]}]`)
4. **Parallel Checking**: Runs clang-tidy on multiple files simultaneously
5. **Result Collection**: Aggregates and categorizes all findings

### Output

The script provides:
- List of changed C++ source files found
- Progress indicator for each file being checked
- Full clang-tidy output for files with issues
- Summary: checked count, error count, warning count

**Exit Codes:**
- `0`: All checks passed or warnings only
- `1`: Errors found or clang-tidy not installed

### Example

```bash
# Check changes compared to main branch with 8 parallel jobs
./tidy_changed_files.sh main 8

# Check changes with default settings
./tidy_changed_files.sh

# Check changes on 4 cores explicitly
./tidy_changed_files.sh dev-v0.6 4
```

**Output Example:**
```
Running clang-tidy on changed files compared to main...
Using 8 parallel jobs
Found changed C++ source files:
  - src/example.cpp
  - src/foo.cpp
Total: 2 file(s)
Running clang-tidy in parallel...

Running: clang-tidy "src/example.cpp" --line-filter="[{\"name\":\"src/example.cpp\",\"lines\":[[10,15],[20,25]]}]"
Running: clang-tidy "src/foo.cpp" --line-filter="[{\"name\":\"src/foo.cpp\",\"lines\":[[5,10]]}]"
✓ src/example.cpp: No issues found
⚠ src/foo.cpp: Found warnings
[clang-tidy output details...]

========================================
Summary:
  Checked: 2 file(s)
  Errors: 0
  Warnings: 1
clang-tidy check completed with warnings.
```

---

## Common Features

Both scripts share these characteristics:

### Line-Level Processing

Instead of processing entire files, both scripts:
1. Parse `git diff` output to identify changed line ranges
2. Apply formatting/checking only to those specific lines
3. Skip files with no relevant changes

This approach:
- **Speeds up processing**: Only analyzes what changed
- **Reduces noise**: Only flags issues you introduced
- **Plays nice with legacy code**: Won't reformat/check old code

### Git Integration

Both scripts analyze:
- **Committed changes**: Differences between current HEAD and base branch
- **Uncommitted changes**: Both staged and unstaged modifications

This ensures all your work is checked, whether committed or not.

### Color-Coded Output

Both scripts use color-coded output for clarity:
- 🟢 **Green (✓)**: Success
- 🟡 **Yellow (⚠)**: Warnings or informational messages
- 🔵 **Blue (-)**: Skipped items
- 🔴 **Red (✗)**: Errors

---

## Prerequisites

### System Dependencies

**clang-format** (for format_changed_files.sh):
```bash
# macOS
brew install clang-format

# Ubuntu/Debian
sudo apt-get install clang-format

# CentOS/RHEL
sudo yum install clang-tools-extra
```

**clang-tidy** (for tidy_changed_files.sh):
```bash
# macOS
brew install llvm
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"

# Ubuntu/Debian
sudo apt-get install clang-tidy

# CentOS/RHEL
sudo yum install clang-tools-extra
```

**Optional - GNU parallel** (for faster clang-tidy):
```bash
# macOS
brew install parallel

# Ubuntu/Debian
sudo apt-get install parallel
```

### Project Setup

For clang-tidy to work properly, you need:

1. **compile_commands.json**: Generate with CMake
   ```bash
   cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
   ln -s build/compile_commands.json .
   ```

2. **.clang-format** (optional): Place in project root for custom formatting rules
   ```yaml
   BasedOnStyle: Google
   IndentWidth: 4
   ColumnLimit: 100
   ```

3. **.clang-tidy** (optional): Place in project root for custom analysis rules
   ```yaml
   Checks: '-*,readability-*,modernize-*,performance-*'
   ```

---

## Usage Examples

### Typical Workflow

```bash
# 1. Make changes to your code
vim src/example.cpp

# 2. Format your changes
./format_changed_files.sh main

# 3. Run static analysis
./tidy_changed_files.sh main

# 4. Fix any issues reported
vim src/example.cpp

# 5. Re-run checks
./format_changed_files.sh main
./tidy_changed_files.sh main

# 6. Commit when clean
git add -A
git commit -m "Add new feature"
```

### Pre-commit Integration

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
set -e

echo "Running clang-format..."
./clang/format_changed_files.sh HEAD

echo "Running clang-tidy..."
./clang/tidy_changed_files.sh HEAD

echo "All checks passed!"
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
- name: Check C++ code quality
  run: |
    ./clang/format_changed_files.sh origin/main
    git diff --exit-code || (echo "Code not formatted!" && exit 1)
    ./clang/tidy_changed_files.sh origin/main
```

---

## Troubleshooting

### "Base branch does not exist"

Make sure you've fetched the branch:
```bash
git fetch origin main
```

### "compile_commands.json not found"

Generate it with CMake:
```bash
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
ln -s build/compile_commands.json .
```

### clang-tidy is slow

Use parallel execution:
```bash
# Use all CPU cores
./tidy_changed_files.sh main $(nproc)

# Install GNU parallel for best performance
brew install parallel  # macOS
sudo apt-get install parallel  # Linux
```

### No files detected

The scripts only detect changes in:
- **format_changed_files.sh**: .cc, .h, .cpp, .hpp files
- **tidy_changed_files.sh**: .cc, .cpp files (source files only)

Make sure your files match these extensions and have actual changes compared to the base branch.

---

## Script Architecture

### Line Range Detection (format_changed_files.sh)

```bash
# Parses git diff output like:
# @@ -10,5 +10,7 @@ 
# Generates clang-format arguments like:
# --lines=10:16 --lines=25:30
```

### Line Filter Generation (tidy_changed_files.sh)

```bash
# Parses git diff output like:
# @@ -10,5 +10,7 @@
# Generates JSON line filter like:
# [{"name":"file.cpp","lines":[[10,16],[25,30]]}]
```

This allows clang-tidy to focus only on changed lines, dramatically reducing analysis time and noise.
