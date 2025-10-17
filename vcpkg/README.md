# vcpkg C++ Project Setup Scripts

Scripts for setting up and managing vcpkg-based C++ projects.

## Available Scripts

- `setup_vcpkg_project.sh` - One-click setup script for vcpkg environment
- `create_cpp_project.sh` - Generate complete C++ project template with vcpkg support

## Documentation

- [SETUP_GUIDE.md](./SETUP_GUIDE.md) - vcpkg environment setup guide
- [PROJECT_TEMPLATE_GUIDE.md](./PROJECT_TEMPLATE_GUIDE.md) - C++ project template generator guide

## Quick Start

### Setup vcpkg Environment

```bash
# Basic setup with default vcpkg location (~/vcpkg)
./setup_vcpkg_project.sh

# Custom vcpkg location with CMake preset generation
./setup_vcpkg_project.sh --vcpkg-root=/opt/vcpkg --with-cmake-preset

# Show all options
./setup_vcpkg_project.sh --help
```

### Create New C++ Project

```bash
# Create a basic project
./create_cpp_project.sh myproject

# Create project with tests and common dependencies
./create_cpp_project.sh myproject --with-tests --dependencies=fmt,spdlog,gtest

# Create full-featured project
./create_cpp_project.sh myproject --with-tests --with-examples --cpp-std=20 \
  --description="My awesome C++ project" \
  --author="Your Name"

# Show all options
./create_cpp_project.sh --help
```
