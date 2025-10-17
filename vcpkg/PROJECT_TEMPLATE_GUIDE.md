# C++ Project Template Generator Guide

Complete guide for generating modern C++ project templates with vcpkg support.

## Table of Contents

- [Overview](#overview)
- [create_cpp_project.sh](#create_cpp_projectsh)
- [Usage Examples](#usage-examples)
- [Generated Project Structure](#generated-project-structure)
- [Customization Options](#customization-options)
- [Working with Generated Projects](#working-with-generated-projects)

## Overview

The `create_cpp_project.sh` script generates a complete, ready-to-use C++ project with:

- Modern CMake configuration (3.17+)
- vcpkg dependency management
- Professional project structure
- Optional test framework (GoogleTest)
- Optional examples
- Build scripts
- Git repository initialization
- Common development files (.gitignore, README, LICENSE)

## create_cpp_project.sh

### Features

- **Modern C++ Standards**: Support for C++11/14/17/20/23
- **Dependency Management**: Automatic vcpkg.json generation
- **CMake Integration**: Professional CMakeLists.txt with best practices
- **Testing Support**: Optional GoogleTest integration
- **Examples**: Optional example programs
- **Multiple Licenses**: MIT, Apache, GPL, BSD
- **Custom Namespace**: Configurable C++ namespace
- **Build Scripts**: Ready-to-use build automation

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `project-name` | Project name (required) | - |
| `--path=PATH` | Project root path | Current directory |
| `--cpp-std=STD` | C++ standard (11\|14\|17\|20\|23) | 17 |
| `--with-tests` | Include test structure with GoogleTest | false |
| `--with-examples` | Include examples directory | false |
| `--license=TYPE` | License (MIT\|Apache\|GPL\|BSD) | MIT |
| `--vcpkg-root=PATH` | Path to vcpkg | ~/vcpkg |
| `--description=TEXT` | Project description | Auto-generated |
| `--author=NAME` | Author name | From git config |
| `--dependencies=LIST` | Comma-separated vcpkg dependencies | fmt,spdlog |
| `--namespace=NAME` | C++ namespace | project name in snake_case |

## Usage Examples

### Basic Project

```bash
./create_cpp_project.sh myproject
```

Creates a minimal project with:
- C++17 standard
- fmt and spdlog dependencies
- MIT license
- Basic library and executable structure

### Project with Tests

```bash
./create_cpp_project.sh myproject --with-tests --dependencies=fmt,spdlog,gtest
```

Includes:
- GoogleTest framework
- Test directory with example tests
- CTest integration

### Full-Featured Project

```bash
./create_cpp_project.sh myproject \
  --with-tests \
  --with-examples \
  --cpp-std=20 \
  --description="High-performance data processing library" \
  --author="Your Name" \
  --license=Apache \
  --dependencies=fmt,spdlog,gtest,nlohmann-json,boost-system
```

Creates a comprehensive project with:
- C++20 features
- Multiple dependencies
- Tests and examples
- Apache 2.0 license
- Custom description

### Custom Location and Namespace

```bash
./create_cpp_project.sh myproject \
  --path=/path/to/workspace \
  --namespace=mycompany::myproject \
  --vcpkg-root=/opt/vcpkg
```

Generates project at custom location with:
- Custom namespace structure
- Custom vcpkg installation path

### Web Service Project Example

```bash
./create_cpp_project.sh webservice \
  --cpp-std=20 \
  --with-tests \
  --description="RESTful web service" \
  --dependencies=fmt,spdlog,gtest,crow,nlohmann-json
```

### Data Science Project Example

```bash
./create_cpp_project.sh dataproc \
  --cpp-std=17 \
  --with-tests \
  --with-examples \
  --description="Data processing pipeline" \
  --dependencies=fmt,spdlog,gtest,arrow,parquet
```

## Generated Project Structure

### Basic Structure

```
myproject/
├── CMakeLists.txt              # Root CMake configuration
├── CMakeUserPresets.json       # CMake presets with vcpkg
├── vcpkg.json                  # Dependencies manifest
├── vcpkg-configuration.json    # vcpkg registry configuration
├── .gitignore                  # Git ignore patterns
├── LICENSE                     # License file
├── README.md                   # Project documentation
├── include/
│   └── myproject/
│       └── example.h           # Public headers
├── src/
│   ├── CMakeLists.txt         # Source CMake config
│   ├── main.cpp               # Executable entry point
│   └── myproject/
│       └── example.cpp        # Library implementation
├── cmake/
│   └── myprojectConfig.cmake.in  # Package config template
└── scripts/
    └── build.sh               # Build automation script
```

### With Tests (--with-tests)

```
tests/
├── CMakeLists.txt
└── test_example.cpp           # Unit tests
```

### With Examples (--with-examples)

```
examples/
├── CMakeLists.txt
└── simple_example.cpp         # Example programs
```

## Generated Files Details

### Root CMakeLists.txt

Professional CMake configuration with:
- Modern CMake practices (target-based)
- Dependency management
- Compiler warnings (-Wall -Wextra -Wpedantic)
- Install targets
- Package config generation
- Testing support (if enabled)

### vcpkg.json

Dependency manifest:
```json
{
  "name": "myproject",
  "version": "0.1.0",
  "description": "Project description",
  "dependencies": [
    "fmt",
    "spdlog"
  ]
}
```

### CMakeUserPresets.json

Ready-to-use CMake presets:
- `default` - Debug build
- `release` - Release build
- Test presets with output on failure

### Source Files

Example library with:
- Header-only interface (`include/myproject/example.h`)
- Implementation (`src/myproject/example.cpp`)
- Main executable (`src/main.cpp`)
- Uses spdlog for logging
- Uses fmt for formatting

### Test Files (if enabled)

GoogleTest examples:
- Test fixture setup
- Example unit tests
- CTest integration

### Build Script

Convenient build automation:
```bash
./scripts/build.sh              # Debug build
./scripts/build.sh --release    # Release build
./scripts/build.sh --clean      # Clean rebuild
```

## Working with Generated Projects

### Initial Setup

After generating the project:

```bash
cd myproject

# Install dependencies
vcpkg install

# Configure
cmake --preset=default

# Build
cmake --build build

# Run
./build/bin/myproject
```

### Using the Build Script

```bash
# Debug build
./scripts/build.sh

# Release build
./scripts/build.sh --release

# Clean rebuild
./scripts/build.sh --clean

# Release clean rebuild
./scripts/build.sh --release --clean
```

### Running Tests

If generated with `--with-tests`:

```bash
# Build tests
cmake --build build

# Run all tests
ctest --test-dir build --output-on-failure

# Run specific test
./build/bin/myproject_tests --gtest_filter=ExampleTest.Add
```

### Building Examples

If generated with `--with-examples`:

```bash
cmake --build build
./build/bin/simple_example
```

### Adding New Dependencies

1. Edit `vcpkg.json`:
```json
{
  "dependencies": [
    "fmt",
    "spdlog",
    "nlohmann-json"  // Add new dependency
  ]
}
```

2. Update root `CMakeLists.txt`:
```cmake
find_package(nlohmann_json CONFIG REQUIRED)
```

3. Link in `src/CMakeLists.txt`:
```cmake
target_link_libraries(myproject
    PUBLIC
        fmt::fmt
        spdlog::spdlog
        nlohmann_json::nlohmann_json
)
```

4. Install and rebuild:
```bash
vcpkg install
cmake --build build
```

### Adding New Source Files

1. Create header in `include/myproject/`:
```cpp
// include/myproject/myclass.h
#pragma once
namespace myproject {
class MyClass { /* ... */ };
}
```

2. Create implementation in `src/myproject/`:
```cpp
// src/myproject/myclass.cpp
#include "myproject/myclass.h"
// Implementation
```

3. Add to `src/CMakeLists.txt`:
```cmake
add_library(myproject
    myproject/example.cpp
    myproject/myclass.cpp  # Add new file
)
```

### Adding New Tests

Create new test file in `tests/`:

```cpp
// tests/test_myclass.cpp
#include "myproject/myclass.h"
#include <gtest/gtest.h>

TEST(MyClassTest, BasicTest) {
    // Your test
}
```

Add to `tests/CMakeLists.txt`:

```cmake
add_executable(myproject_tests
    test_example.cpp
    test_myclass.cpp  # Add new test
)
```

## Customization Options

### Project Name

Must start with a letter and contain only:
- Letters (a-z, A-Z)
- Numbers (0-9)
- Hyphens (-)
- Underscores (_)

Examples:
- ✅ `my-project`, `MyLib2`, `data_processor`
- ❌ `2fast`, `my project`, `test@lib`

### C++ Standard

Supported standards:
- `11` - C++11 (legacy)
- `14` - C++14
- `17` - C++17 (default, widely supported)
- `20` - C++20 (modern features)
- `23` - C++23 (bleeding edge)

### Namespace

By default, converts project name to snake_case:
- `MyProject` → `my_project`
- `my-lib` → `my_lib`
- `DataProcessor` → `dataprocessor`

Custom namespaces:
```bash
--namespace=company::product
--namespace=mylib::v2
```

### License Types

Supported licenses:
- `MIT` - Permissive, simple (default)
- `Apache` - Permissive with patent grant
- `GPL` - Copyleft
- `BSD` - Permissive, BSD-style

### Common Dependency Combinations

**CLI Application:**
```bash
--dependencies=fmt,spdlog,CLI11
```

**Web Service:**
```bash
--dependencies=fmt,spdlog,crow,nlohmann-json
```

**Database Application:**
```bash
--dependencies=fmt,spdlog,libpqxx,nlohmann-json
```

**Game/Graphics:**
```bash
--dependencies=fmt,spdlog,sdl2,glm
```

**Scientific Computing:**
```bash
--dependencies=fmt,spdlog,eigen3,boost-math
```

## Integration with IDEs

### Visual Studio Code

Generated project includes:
- `compile_commands.json` (via CMAKE_EXPORT_COMPILE_COMMANDS)
- Works with C/C++ extension
- CMake Tools extension compatible

### CLion

- Automatically detects CMake project
- Uses CMakeUserPresets.json
- vcpkg integration works out-of-the-box

### Visual Studio

- Open folder with CMake support
- Presets automatically detected
- vcpkg toolchain recognized

## Best Practices

### After Generation

1. **Review generated files** - Customize as needed
2. **Update README.md** - Add project-specific information
3. **Configure CI/CD** - Add GitHub Actions, GitLab CI, etc.
4. **Add documentation** - Use Doxygen or similar
5. **Configure code formatting** - Add .clang-format

### Development Workflow

1. **Keep dependencies updated**: Regularly update vcpkg baseline
2. **Write tests first**: TDD approach with provided test structure
3. **Use CMake presets**: Consistent builds across environments
4. **Leverage build script**: Automation saves time

### Project Organization

- Keep public headers in `include/`
- Implementation details in `src/`
- One class per file pair (header + implementation)
- Tests mirror source structure

## Troubleshooting

### Project already exists

```bash
# Error: Project directory already exists
# Solution: Choose different name or location
./create_cpp_project.sh myproject2
# or
./create_cpp_project.sh myproject --path=/different/location
```

### vcpkg not found

```bash
# Specify vcpkg location
./create_cpp_project.sh myproject --vcpkg-root=/path/to/vcpkg

# Or install vcpkg first
../setup_vcpkg_project.sh
```

### CMake version too old

```bash
# Check version
cmake --version

# Update CMake (Ubuntu/Debian)
sudo apt-get install cmake

# Or use pip
pip install cmake --upgrade
```

### Compiler errors

Ensure you have a C++ compiler:

```bash
# Check compiler
g++ --version    # or clang++ --version

# Install (Ubuntu/Debian)
sudo apt-get install build-essential

# Install (macOS)
xcode-select --install
```

## References

- [Modern CMake Practices](https://cliutils.gitlab.io/modern-cmake/)
- [vcpkg Documentation](https://vcpkg.io/)
- [GoogleTest Documentation](https://google.github.io/googletest/)
- [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/)

## License

MIT License - Free to use and modify.
