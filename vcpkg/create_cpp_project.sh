#!/bin/bash
# Create a complete C++ project template with vcpkg support
# This script generates a ready-to-use C++ project structure with:
# - CMake configuration
# - vcpkg integration
# - Modern C++ project structure
# - Example code and tests

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 <project-name> [OPTIONS]

Create a complete C++ project template with vcpkg support

ARGUMENTS:
    project-name                Name of the project (required)

OPTIONS:
    --help                      Show this help message
    --path=PATH                 Project root path (default: current directory)
    --cpp-std=STD              C++ standard (11|14|17|20|23, default: 17)
    --with-tests               Include test structure with GoogleTest
    --with-examples            Include examples directory
    --license=TYPE             License type (MIT|Apache|GPL|BSD, default: MIT)
    --vcpkg-root=PATH          Path to vcpkg (default: ~/vcpkg)
    --description=TEXT         Project description
    --author=NAME              Author name
    --dependencies=LIST        Comma-separated vcpkg dependencies (e.g., fmt,spdlog,gtest)
    --namespace=NAME           C++ namespace (default: project name in snake_case)

EXAMPLES:
    # Basic project
    $0 myproject

    # Project with tests and common dependencies
    $0 myproject --with-tests --dependencies=fmt,spdlog,gtest

    # Full featured project
    $0 myproject --with-tests --with-examples --cpp-std=20 \\
      --description="My awesome C++ project" \\
      --author="Your Name" \\
      --dependencies=fmt,spdlog,gtest,nlohmann-json

    # Custom location and namespace
    $0 myproject --path=/path/to/projects --namespace=mycompany::myproject

EOF
}

# Default values
PROJECT_NAME=""
PROJECT_PATH="."
CPP_STANDARD="17"
WITH_TESTS=false
WITH_EXAMPLES=false
LICENSE="MIT"
VCPKG_ROOT="${VCPKG_ROOT:-${HOME}/vcpkg}"
DESCRIPTION=""
AUTHOR=""
DEPENDENCIES=""
NAMESPACE=""

# Parse arguments
if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
fi

PROJECT_NAME="$1"
shift

for arg in "$@"; do
    case $arg in
        --help)
            show_usage
            exit 0
            ;;
        --path=*)
            PROJECT_PATH="${arg#*=}"
            ;;
        --cpp-std=*)
            CPP_STANDARD="${arg#*=}"
            ;;
        --with-tests)
            WITH_TESTS=true
            ;;
        --with-examples)
            WITH_EXAMPLES=true
            ;;
        --license=*)
            LICENSE="${arg#*=}"
            ;;
        --vcpkg-root=*)
            VCPKG_ROOT="${arg#*=}"
            ;;
        --description=*)
            DESCRIPTION="${arg#*=}"
            ;;
        --author=*)
            AUTHOR="${arg#*=}"
            ;;
        --dependencies=*)
            DEPENDENCIES="${arg#*=}"
            ;;
        --namespace=*)
            NAMESPACE="${arg#*=}"
            ;;
        *)
            print_error "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate project name
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    print_error "Invalid project name. Must start with a letter and contain only letters, numbers, hyphens, and underscores."
    exit 1
fi

# Validate C++ standard
if [[ ! "$CPP_STANDARD" =~ ^(11|14|17|20|23)$ ]]; then
    print_error "Invalid C++ standard: $CPP_STANDARD. Must be 11, 14, 17, 20, or 23."
    exit 1
fi

# Set defaults
if [[ -z "$DESCRIPTION" ]]; then
    DESCRIPTION="A C++ project built with CMake and vcpkg"
fi

if [[ -z "$AUTHOR" ]]; then
    AUTHOR=$(git config user.name 2>/dev/null || echo "Your Name")
fi

# Convert project name to namespace if not specified
if [[ -z "$NAMESPACE" ]]; then
    NAMESPACE=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr '-' '_')
fi

# Create full project path
FULL_PROJECT_PATH="${PROJECT_PATH}/${PROJECT_NAME}"

# Check if project directory already exists
if [[ -d "$FULL_PROJECT_PATH" ]]; then
    print_error "Project directory already exists: $FULL_PROJECT_PATH"
    exit 1
fi

print_info "Creating C++ project: $PROJECT_NAME"
print_info "Location: $FULL_PROJECT_PATH"
print_info "C++ Standard: $CPP_STANDARD"
print_info "Author: $AUTHOR"
print_info "Namespace: $NAMESPACE"
echo ""

# Create directory structure
create_directories() {
    print_info "Creating directory structure..."
    
    mkdir -p "$FULL_PROJECT_PATH"
    cd "$FULL_PROJECT_PATH"
    
    mkdir -p src
    mkdir -p cmake
    mkdir -p scripts
    
    if [[ "$WITH_TESTS" == true ]]; then
        mkdir -p tests
    fi
    
    if [[ "$WITH_EXAMPLES" == true ]]; then
        mkdir -p examples
    fi
    
    print_success "Directory structure created"
}

# Generate vcpkg.json
generate_vcpkg_manifest() {
    print_info "Generating vcpkg.json..."
    
    # Convert project name to vcpkg-compatible format (lowercase, replace underscore with hyphen)
    local vcpkg_name=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    
    # Build dependencies array
    local deps_list=()
    if [[ -n "$DEPENDENCIES" ]]; then
        IFS=',' read -ra DEPS <<< "$DEPENDENCIES"
        for dep in "${DEPS[@]}"; do
            dep=$(echo "$dep" | xargs)
            deps_list+=("\"$dep\"")
        done
    else
        # Default dependencies
        deps_list=("\"fmt\"" "\"spdlog\"")
        if [[ "$WITH_TESTS" == true ]]; then
            deps_list+=("\"gtest\"")
        fi
    fi
    
    # Generate JSON file
    {
        echo "{"
        echo "  \"name\": \"${vcpkg_name}\","
        echo "  \"version\": \"0.1.0\","
        echo "  \"description\": \"${DESCRIPTION}\","
        echo "  \"dependencies\": ["
        for i in "${!deps_list[@]}"; do
            if [[ $i -eq $((${#deps_list[@]} - 1)) ]]; then
                echo "    ${deps_list[$i]}"
            else
                echo "    ${deps_list[$i]},"
            fi
        done
        echo "  ]"
        echo "}"
    } > vcpkg.json
    
    print_success "vcpkg.json created"
}

# Generate vcpkg-configuration.json
generate_vcpkg_configuration() {
    print_info "Generating vcpkg-configuration.json..."
    
    # Get latest vcpkg baseline if possible
    local baseline="builtin-baseline"
    if [[ -d "$VCPKG_ROOT/.git" ]]; then
        baseline=$(cd "$VCPKG_ROOT" && git rev-parse HEAD 2>/dev/null || echo "builtin-baseline")
    fi
    
    cat > vcpkg-configuration.json << EOF
{
  "default-registry": {
    "kind": "git",
    "repository": "https://github.com/microsoft/vcpkg",
    "baseline": "${baseline}"
  }
}
EOF
    
    print_success "vcpkg-configuration.json created"
}

# Generate root CMakeLists.txt
generate_root_cmake() {
    print_info "Generating root CMakeLists.txt..."
    
    local test_section=""
    if [[ "$WITH_TESTS" == true ]]; then
        test_section="
option(BUILD_TESTS \"Build tests\" ON)

if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
"
    fi
    
    local examples_section=""
    if [[ "$WITH_EXAMPLES" == true ]]; then
        examples_section="
option(BUILD_EXAMPLES \"Build examples\" ON)

if(BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()
"
    fi
    
    cat > CMakeLists.txt << EOF
cmake_minimum_required(VERSION 3.17)

project(${PROJECT_NAME}
    VERSION 0.1.0
    DESCRIPTION "${DESCRIPTION}"
    LANGUAGES CXX
)

# C++ Standard
set(CMAKE_CXX_STANDARD ${CPP_STANDARD})
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Export compile commands for IDE integration
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY \${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY \${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY \${CMAKE_BINARY_DIR}/lib)

# Prevent in-source builds
if("\${PROJECT_SOURCE_DIR}" STREQUAL "\${PROJECT_BINARY_DIR}")
    message(FATAL_ERROR "In-source builds are not allowed")
endif()

# CMake modules
list(APPEND CMAKE_MODULE_PATH \${CMAKE_SOURCE_DIR}/cmake)

# Compiler warnings
if(MSVC)
    add_compile_options(/W4 /WX)
else()
    add_compile_options(-Wall -Wextra -Wpedantic -Werror)
endif()

# Find dependencies
find_package(fmt CONFIG REQUIRED)
find_package(spdlog CONFIG REQUIRED)
${test_section}
# Add subdirectories
add_subdirectory(src)
${examples_section}
# Installation
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

install(TARGETS ${PROJECT_NAME}
    EXPORT ${PROJECT_NAME}Targets
    LIBRARY DESTINATION \${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION \${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION \${CMAKE_INSTALL_BINDIR}
)

install(DIRECTORY src/
    DESTINATION \${CMAKE_INSTALL_INCLUDEDIR}
    FILES_MATCHING PATTERN "*.h"
)

# Generate and install package config files
configure_package_config_file(
    \${CMAKE_SOURCE_DIR}/cmake/${PROJECT_NAME}Config.cmake.in
    \${CMAKE_BINARY_DIR}/${PROJECT_NAME}Config.cmake
    INSTALL_DESTINATION \${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
)

write_basic_package_version_file(
    \${CMAKE_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
    VERSION \${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(FILES
    \${CMAKE_BINARY_DIR}/${PROJECT_NAME}Config.cmake
    \${CMAKE_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
    DESTINATION \${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
)

install(EXPORT ${PROJECT_NAME}Targets
    FILE ${PROJECT_NAME}Targets.cmake
    NAMESPACE ${PROJECT_NAME}::
    DESTINATION \${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
)
EOF
    
    print_success "Root CMakeLists.txt created"
}

# Generate src CMakeLists.txt
generate_src_cmake() {
    print_info "Generating src/CMakeLists.txt..."
    
    cat > src/CMakeLists.txt << EOF
# Library target
add_library(${PROJECT_NAME}
    example.cpp
    example.h
)

target_include_directories(${PROJECT_NAME}
    PUBLIC
        \$<BUILD_INTERFACE:\${CMAKE_SOURCE_DIR}/src>
        \$<INSTALL_INTERFACE:\${CMAKE_INSTALL_INCLUDEDIR}>
)

target_link_libraries(${PROJECT_NAME}
    PUBLIC
        fmt::fmt
        spdlog::spdlog
)

# Executable target
add_executable(${PROJECT_NAME}_app
    main.cpp
)

target_link_libraries(${PROJECT_NAME}_app
    PRIVATE
        ${PROJECT_NAME}
)

set_target_properties(${PROJECT_NAME}_app
    PROPERTIES
        OUTPUT_NAME ${PROJECT_NAME}
)
EOF
    
    print_success "src/CMakeLists.txt created"
}

# Generate header files
generate_headers() {
    print_info "Generating header files..."
    
    cat > src/example.h << EOF
#pragma once

#include <string>

namespace ${NAMESPACE} {

class Example {
public:
    Example();
    ~Example();

    std::string greet(const std::string& name) const;
    int add(int a, int b) const;
};

}  // namespace ${NAMESPACE}
EOF
    
    print_success "Header files created"
}

# Generate source files
generate_sources() {
    print_info "Generating source files..."
    
    cat > src/example.cpp << EOF
#include "example.h"
#include <spdlog/spdlog.h>
#include <fmt/format.h>

namespace ${NAMESPACE} {

Example::Example() {
    spdlog::info("Example object created");
}

Example::~Example() {
    spdlog::info("Example object destroyed");
}

std::string Example::greet(const std::string& name) const {
    return fmt::format("Hello, {}!", name);
}

int Example::add(int a, int b) const {
    return a + b;
}

}  // namespace ${NAMESPACE}
EOF
    
    cat > src/main.cpp << EOF
#include "example.h"
#include <spdlog/spdlog.h>
#include <iostream>

int main() {
    spdlog::info("Starting ${PROJECT_NAME}...");

    ${NAMESPACE}::Example example;
    
    std::cout << example.greet("World") << std::endl;
    std::cout << "2 + 3 = " << example.add(2, 3) << std::endl;

    spdlog::info("${PROJECT_NAME} finished successfully");
    return 0;
}
EOF
    
    print_success "Source files created"
}

# Generate test files
generate_tests() {
    if [[ "$WITH_TESTS" != true ]]; then
        return
    fi
    
    print_info "Generating test files..."
    
    cat > tests/CMakeLists.txt << EOF
find_package(GTest CONFIG REQUIRED)

add_executable(${PROJECT_NAME}_tests
    test_example.cpp
)

target_link_libraries(${PROJECT_NAME}_tests
    PRIVATE
        ${PROJECT_NAME}
        GTest::gtest
        GTest::gtest_main
)

include(GoogleTest)
gtest_discover_tests(${PROJECT_NAME}_tests)
EOF
    
    cat > tests/test_example.cpp << EOF
#include "example.h"
#include <gtest/gtest.h>

using namespace ${NAMESPACE};

TEST(ExampleTest, Greet) {
    Example example;
    EXPECT_EQ(example.greet("World"), "Hello, World!");
}

TEST(ExampleTest, Add) {
    Example example;
    EXPECT_EQ(example.add(2, 3), 5);
    EXPECT_EQ(example.add(-1, 1), 0);
}
EOF
    
    print_success "Test files created"
}

# Generate examples
generate_examples() {
    if [[ "$WITH_EXAMPLES" != true ]]; then
        return
    fi
    
    print_info "Generating example files..."
    
    cat > examples/CMakeLists.txt << EOF
add_executable(simple_example
    simple_example.cpp
)

target_link_libraries(simple_example
    PRIVATE
        ${PROJECT_NAME}
)
EOF
    
    cat > examples/simple_example.cpp << EOF
#include "example.h"
#include <iostream>

int main() {
    ${NAMESPACE}::Example example;
    
    std::cout << example.greet("from example") << std::endl;
    std::cout << "10 + 20 = " << example.add(10, 20) << std::endl;
    
    return 0;
}
EOF
    
    print_success "Example files created"
}

# Generate CMake package config
generate_cmake_config() {
    print_info "Generating CMake package config..."
    
    cat > cmake/${PROJECT_NAME}Config.cmake.in << 'EOF'
@PACKAGE_INIT@

include(CMakeFindDependencyMacro)

find_dependency(fmt CONFIG REQUIRED)
find_dependency(spdlog CONFIG REQUIRED)

include("${CMAKE_CURRENT_LIST_DIR}/@PROJECT_NAME@Targets.cmake")

check_required_components(@PROJECT_NAME@)
EOF
    
    print_success "CMake package config created"
}

# Generate CMakePresets.json (for version control)
generate_cmake_presets() {
    print_info "Generating CMakePresets.json..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: Add PATH and tool settings to avoid GNU binutils issues
        cat > CMakePresets.json << 'EOF'
{
  "version": 3,
  "configurePresets": [
    {
      "name": "vcpkg",
      "description": "Configure with vcpkg toolchain",
      "generator": "Ninja",
      "binaryDir": "${sourceDir}/build",
      "environment": {
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:$penv{PATH}"
      },
      "cacheVariables": {
        "CMAKE_TOOLCHAIN_FILE": "$env{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake",
        "CMAKE_C_COMPILER": "clang",
        "CMAKE_CXX_COMPILER": "clang++",
        "CMAKE_AR": "/usr/bin/ar",
        "CMAKE_RANLIB": "/usr/bin/ranlib"
      }
    }
  ]
}
EOF
    else
        # Linux: Standard configuration
        cat > CMakePresets.json << 'EOF'
{
  "version": 3,
  "configurePresets": [
    {
      "name": "vcpkg",
      "description": "Configure with vcpkg toolchain",
      "generator": "Ninja",
      "binaryDir": "${sourceDir}/build",
      "cacheVariables": {
        "CMAKE_TOOLCHAIN_FILE": "$env{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
      }
    }
  ]
}
EOF
    fi
    
    print_success "CMakePresets.json created"
}

# Generate CMakeUserPresets.json (local, not for version control)
generate_cmake_user_presets() {
    print_info "Generating CMakeUserPresets.json..."
    
    cat > CMakeUserPresets.json << EOF
{
  "version": 3,
  "configurePresets": [
    {
      "name": "default",
      "inherits": "vcpkg",
      "displayName": "Debug",
      "description": "Debug build with vcpkg",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Debug"
      }
    },
    {
      "name": "release",
      "inherits": "vcpkg",
      "displayName": "Release",
      "description": "Release build with vcpkg",
      "binaryDir": "\${sourceDir}/build-release",
      "cacheVariables": {
        "CMAKE_BUILD_TYPE": "Release"
      }
    }
  ]
}
EOF
    
    print_success "CMakeUserPresets.json created"
}

# Generate .gitignore
generate_gitignore() {
    print_info "Generating .gitignore..."
    
    cat > .gitignore << EOF
# Build directories
build/
build-*/
cmake-build-*/
out/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# vcpkg
vcpkg_installed/

# CMake user presets (local configuration)
CMakeUserPresets.json

# Compiled files
*.o
*.obj
*.so
*.dylib
*.dll
*.exe
*.out
*.app

# CMake
CMakeCache.txt
CMakeFiles/
cmake_install.cmake
compile_commands.json
CTestTestfile.cmake
_deps/

# OS
.DS_Store
Thumbs.db
EOF
    
    print_success ".gitignore created"
}

# Generate README.md
generate_readme() {
    print_info "Generating README.md..."
    
    local test_section=""
    if [[ "$WITH_TESTS" == true ]]; then
        test_section="
## Running Tests

\`\`\`bash
cmake --build build
ctest --test-dir build --output-on-failure
\`\`\`
"
    fi
    
    cat > README.md << EOF
# ${PROJECT_NAME}

${DESCRIPTION}

## Requirements

- CMake 3.17 or higher
- C++${CPP_STANDARD} compatible compiler
- vcpkg

## Building

### Setup vcpkg dependencies

\`\`\`bash
vcpkg install
\`\`\`

### Configure and build

\`\`\`bash
cmake --preset=default
cmake --build build
\`\`\`

### Run

\`\`\`bash
./build/bin/${PROJECT_NAME}
\`\`\`
${test_section}
## Project Structure

\`\`\`
${PROJECT_NAME}/
├── src/                        # Source files
│   ├── example.h              # Header files
│   ├── example.cpp            # Implementation files
│   └── main.cpp               # Executable entry point
$(if [[ "$WITH_TESTS" == true ]]; then echo "├── tests/                      # Unit tests"; fi)
$(if [[ "$WITH_EXAMPLES" == true ]]; then echo "├── examples/                   # Example programs"; fi)
├── cmake/                      # CMake modules
├── CMakeLists.txt             # Root CMake file
├── vcpkg.json                 # Dependencies manifest
└── README.md
\`\`\`

## License

${LICENSE}

## Author

${AUTHOR}
EOF
    
    print_success "README.md created"
}

# Generate LICENSE file
generate_license() {
    print_info "Generating LICENSE..."
    
    local year=$(date +%Y)
    
    case "$LICENSE" in
        MIT)
            cat > LICENSE << EOF
MIT License

Copyright (c) ${year} ${AUTHOR}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
            ;;
        Apache)
            cat > LICENSE << EOF
Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

Copyright ${year} ${AUTHOR}

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
EOF
            ;;
        *)
            cat > LICENSE << EOF
Copyright (c) ${year} ${AUTHOR}

All rights reserved.
EOF
            ;;
    esac
    
    print_success "LICENSE created"
}

# Generate build script
generate_build_script() {
    print_info "Generating build script..."
    
    cat > scripts/build.sh << 'EOF'
#!/bin/bash
set -e

BUILD_TYPE="Debug"
CLEAN_BUILD=false

for arg in "$@"; do
    case $arg in
        --release)
            BUILD_TYPE="Release"
            ;;
        --clean)
            CLEAN_BUILD=true
            ;;
        --help)
            echo "Usage: $0 [--release] [--clean] [--help]"
            exit 0
            ;;
    esac
done

if [ "$CLEAN_BUILD" = true ]; then
    echo "Cleaning build directory..."
    rm -rf build
fi

echo "Building in $BUILD_TYPE mode..."

if [ "$BUILD_TYPE" = "Release" ]; then
    cmake --preset=release
else
    cmake --preset=default
fi

cmake --build build

echo "Build completed successfully!"
EOF
    
    chmod +x scripts/build.sh
    
    print_success "Build script created"
}

# Initialize git repository
init_git_repo() {
    print_info "Initializing git repository..."
    
    git init
    git add .
    git commit -m "Initial commit: ${PROJECT_NAME} project structure"
    
    print_success "Git repository initialized"
}

# Print summary
print_summary() {
    echo ""
    echo "========================================"
    print_success "Project created successfully!"
    echo "========================================"
    echo ""
    print_info "Project: ${PROJECT_NAME}"
    print_info "Location: ${FULL_PROJECT_PATH}"
    print_info "C++ Standard: C++${CPP_STANDARD}"
    print_info "License: ${LICENSE}"
    echo ""
    print_info "Next steps:"
    echo ""
    echo "  1. Navigate to project directory:"
    echo "     cd ${FULL_PROJECT_PATH}"
    echo ""
    echo "  2. Install vcpkg dependencies:"
    echo "     vcpkg install"
    echo ""
    echo "  3. Build the project:"
    echo "     ./scripts/build.sh"
    echo "     # or use CMake directly:"
    echo "     cmake --preset=default"
    echo "     cmake --build build"
    echo ""
    echo "  4. Run the application:"
    echo "     ./build/bin/${PROJECT_NAME}"
    echo ""
    
    if [[ "$WITH_TESTS" == true ]]; then
        echo "  5. Run tests:"
        echo "     ctest --test-dir build --output-on-failure"
        echo ""
    fi
    
    echo "Happy coding! 🚀"
    echo ""
}

# Main execution
main() {
    create_directories
    generate_vcpkg_manifest
    generate_vcpkg_configuration
    generate_root_cmake
    generate_src_cmake
    generate_headers
    generate_sources
    generate_tests
    generate_examples
    generate_cmake_config
    generate_cmake_presets
    generate_cmake_user_presets
    generate_gitignore
    generate_readme
    generate_license
    generate_build_script
    init_git_repo
    print_summary
}

# Run main
main
