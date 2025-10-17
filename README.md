# Dev Scripts

A collection of development automation scripts for C++ projects with vcpkg, CMake, and Clang tooling integration.

## Overview

This repository contains shell scripts to streamline common C++ development tasks:
- Setting up vcpkg-based development environments
- Generating modern CMake project templates
- Running code formatting and static analysis on changed files

All scripts are designed to be cross-platform (Linux/macOS) and follow best practices for C++ project management.

## Available Script Collections

### [vcpkg/](./vcpkg/) - C++ Project Setup with vcpkg

Scripts for managing vcpkg-based C++ projects:

- **`setup_vcpkg_project.sh`** - One-click setup for vcpkg environment
  - Detects OS and installs required dependencies (git, cmake, ninja, curl, etc.)
  - Clones and bootstraps vcpkg
  - Generates CMakeUserPresets.json for local development
  - Configures environment variables

- **`create_cpp_project.sh`** - Generate complete C++ project templates
  - Creates project structure with src/, tests/, examples/, cmake/ directories
  - Generates vcpkg.json manifest with specified dependencies
  - Creates CMakeLists.txt with modern CMake practices
  - Generates CMakePresets.json with platform-specific toolchain configuration
  - Includes example code with optional tests (Google Test) and examples
  - Supports interactive and command-line modes

**Documentation:** [vcpkg/README.md](./vcpkg/README.md)

**Detailed Guides:**
- [SETUP_GUIDE.md](./vcpkg/SETUP_GUIDE.md) - vcpkg environment setup
- [PROJECT_TEMPLATE_GUIDE.md](./vcpkg/PROJECT_TEMPLATE_GUIDE.md) - Project template generator

### [clang/](./clang/) - Code Quality Tools

Scripts for running Clang tools on changed files only (line-level analysis):

- **`format_changed_files.sh`** - Format changed C++ files with clang-format
  - Only formats lines that were modified (git-aware)
  - Compares against base branch to identify changes
  - Supports both committed and uncommitted changes
  - Color-coded output with detailed summary

- **`tidy_changed_files.sh`** - Run clang-tidy static analysis on changed files
  - Only analyzes lines that were modified (git-aware)
  - Parallel execution support for faster processing
  - Uses compile_commands.json for accurate analysis
  - Categorizes issues as errors or warnings
  - Configurable number of parallel jobs

**Documentation:** [clang/README.md](./clang/README.md)

**Detailed Guide:** [clang/CLANG_TOOLS_GUIDE.md](./clang/CLANG_TOOLS_GUIDE.md)

## Quick Start

### Setting up a new C++ project with vcpkg

```bash
# 1. Setup vcpkg environment
cd vcpkg/
./setup_vcpkg_project.sh

# 2. Create new project
./create_cpp_project.sh

# Follow interactive prompts to configure:
# - Project name and description
# - Dependencies (fmt, spdlog, gtest, etc.)
# - Optional tests and examples

# 3. Build the project
cd your-project/
cmake --preset vcpkg
cmake --build build
./build/your-project
```

### Running code quality checks

```bash
# Format changed files compared to main branch
cd clang/
./format_changed_files.sh main

# Run static analysis on changed files
./tidy_changed_files.sh main 8  # 8 parallel jobs
```

## Features

### vcpkg Scripts

- ✅ Cross-platform support (Linux: RHEL/CentOS/TencentOS/Ubuntu/Debian, macOS)
- ✅ Automatic dependency installation
- ✅ Modern CMake with presets (CMakePresets.json + CMakeUserPresets.json)
- ✅ vcpkg manifest mode integration
- ✅ Platform-specific toolchain configuration
- ✅ Organized project structure (headers and sources in src/)
- ✅ Optional Google Test integration
- ✅ Example code generation

### Clang Scripts

- ✅ Line-level formatting/analysis (only changed lines)
- ✅ Git-aware (compares against base branch)
- ✅ Parallel execution support
- ✅ Color-coded output
- ✅ Comprehensive reporting
- ✅ Handles both committed and uncommitted changes

## Platform-Specific Notes

### macOS

The vcpkg scripts include special handling for macOS:
- Uses system BSD ar/ranlib instead of GNU binutils
- Configures CMakePresets.json with Clang toolchain
- Sets PATH to prioritize system tools over Homebrew alternatives

### Linux

Supports multiple distributions:
- RHEL/CentOS/TencentOS: Uses `yum` package manager
- Ubuntu/Debian: Uses `apt-get` package manager

## Prerequisites

### Common Requirements

- Git
- CMake (>= 3.15)
- C++ compiler (Clang or GCC)
- Ninja build system (recommended)

### For vcpkg scripts

- curl (for downloading dependencies)
- zip/unzip (for vcpkg packages)
- tar (for extracting archives)
- pkg-config (Linux)

### For Clang scripts

- clang-format (for formatting)
- clang-tidy (for static analysis)
- GNU parallel (optional, for faster processing)

See individual guides for detailed installation instructions.

## Environment Variables

### VCPKG_ROOT

All scripts respect the `VCPKG_ROOT` environment variable for vcpkg location. Set it in your shell:

```bash
# Add to ~/.bashrc or ~/.zshrc
export VCPKG_ROOT="$HOME/vcpkg"
```

Default location if not set: `$HOME/vcpkg`

## Project Structure

```
dev-scripts/
├── README.md                 # This file
├── vcpkg/                    # vcpkg project setup scripts
│   ├── README.md
│   ├── SETUP_GUIDE.md
│   ├── PROJECT_TEMPLATE_GUIDE.md
│   ├── setup_vcpkg_project.sh
│   └── create_cpp_project.sh
└── clang/                    # Clang tools scripts
    ├── README.md
    ├── CLANG_TOOLS_GUIDE.md
    ├── format_changed_files.sh
    └── tidy_changed_files.sh
```

## Contributing

These scripts are designed to follow best practices for C++ development. Key principles:

1. **Cross-platform compatibility**: Support both Linux and macOS
2. **Modern tooling**: Use latest CMake features, vcpkg manifest mode
3. **Git integration**: Leverage git for intelligent change detection
4. **Performance**: Parallel execution where possible
5. **User-friendly**: Clear output, helpful error messages
6. **Non-invasive**: Only modify what's necessary (line-level changes)

## Troubleshooting

### vcpkg scripts

- **"VCPKG_ROOT not set"**: Set the environment variable or let script use default
- **Build failures on macOS**: Ensure GNU binutils is not in PATH before system tools
- **Missing dependencies**: Run `setup_vcpkg_project.sh` to install system dependencies

### Clang scripts

- **"Base branch does not exist"**: Run `git fetch origin <branch>`
- **"compile_commands.json not found"**: Generate with `cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build`
- **Slow clang-tidy**: Install GNU parallel or increase parallel jobs

See individual guides for detailed troubleshooting.

## License

These scripts are provided as-is for development convenience.

## Links

- [vcpkg Documentation](https://vcpkg.io/)
- [CMake Documentation](https://cmake.org/documentation/)
- [Clang Tools Documentation](https://clang.llvm.org/docs/ClangTools.html)
