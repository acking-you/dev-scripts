# vcpkg C++ Project Setup Guide

Comprehensive guide for setting up vcpkg-based C++ projects.

## Table of Contents

- [Scripts Overview](#scripts-overview)
- [setup_vcpkg_project.sh](#setup_vcpkg_projectsh)
- [Usage Examples](#usage-examples)
- [System Requirements](#system-requirements)
- [Troubleshooting](#troubleshooting)

## Scripts Overview

### setup_vcpkg_project.sh

One-click setup script that automates the entire development environment setup for vcpkg-based C++ projects.

**Features:**
- Automatic OS detection (Linux RHEL/CentOS/TencentOS/Ubuntu/Debian and macOS)
- System dependencies installation (cmake, gcc, ninja, etc.)
- vcpkg installation and bootstrapping
- CMake preset generation
- Environment variable configuration

## setup_vcpkg_project.sh

### Command Line Options

| Option | Description |
|--------|-------------|
| `--help` | Show help message |
| `--vcpkg-root=PATH` | Specify vcpkg installation path (default: ~/vcpkg) |
| `--skip-system-deps` | Skip system dependencies installation |
| `--skip-vcpkg-install` | Skip vcpkg installation (use existing) |
| `--force-reinstall` | Force reinstall vcpkg even if it exists |
| `--with-cmake-preset` | Generate CMakeUserPresets.json |
| `--preset-template=PATH` | Path to CMakeUserPresets.json.template |

## Usage Examples

### Basic Setup

```bash
# Setup with default vcpkg location (~/vcpkg)
./setup_vcpkg_project.sh
```

### Custom vcpkg Location

```bash
# Install vcpkg to a custom directory
./setup_vcpkg_project.sh --vcpkg-root=/opt/vcpkg
```

### With CMake Preset Generation

```bash
# Generate CMakeUserPresets.json automatically
./setup_vcpkg_project.sh --with-cmake-preset
```

### Using a CMake Preset Template

```bash
# Use your project's template
./setup_vcpkg_project.sh --with-cmake-preset --preset-template=./CMakeUserPresets.json.template
```

### Skip System Dependencies

```bash
# If you've already installed system packages
./setup_vcpkg_project.sh --skip-system-deps
```

### Force Reinstall

```bash
# Remove and reinstall vcpkg
./setup_vcpkg_project.sh --force-reinstall
```

## Typical Workflow

### Setting up a New Project

1. **Run the setup script:**
   ```bash
   cd /path/to/your/cpp/project
   /path/to/setup_vcpkg_project.sh --with-cmake-preset
   ```

2. **Create vcpkg.json for dependencies:**
   ```json
   {
     "dependencies": [
       "fmt",
       "spdlog",
       "gtest"
     ]
   }
   ```

3. **Optional: Create vcpkg-configuration.json:**
   ```json
   {
     "default-registry": {
       "kind": "git",
       "baseline": "90cd8f5a2173566615da3d4fbeb1e3aef4445ba4",
       "repository": "https://github.com/microsoft/vcpkg"
     },
     "overlay-ports": ["./overlay"],
     "overlay-triplets": ["./triplets"]
   }
   ```

4. **Install dependencies:**
   ```bash
   ~/vcpkg/vcpkg install
   ```

5. **Configure and build:**
   ```bash
   cmake --preset=default -B build
   cmake --build build
   ```

### Using with Existing Projects

For projects like the reference tcqa-table:

1. **Run setup with template:**
   ```bash
   ./setup_vcpkg_project.sh --with-cmake-preset --preset-template=./CMakeUserPresets.json.template
   ```

2. **Install dependencies:**
   ```bash
   vcpkg install
   ```

3. **Build the project:**
   ```bash
   ./scripts/build.sh --compile_mode=Release
   ```

## System Requirements

### Linux (RHEL/CentOS/TencentOS)
- RHEL/CentOS 7+ or TencentOS 3+
- sudo access for package installation
- Internet connectivity for package downloads

### Linux (Ubuntu/Debian)
- Ubuntu 18.04+ or Debian 10+
- sudo access for package installation
- Internet connectivity for package downloads

### macOS
- macOS 10.15+
- Homebrew installed
- Xcode Command Line Tools

## Installed Dependencies

### Common Build Tools
- git
- cmake (3.17+)
- gcc/g++ or clang
- ninja-build
- ccache
- pkg-config
- curl
- openssl
- wget, tar, zip, unzip

### Platform-Specific Packages

**Linux (RHEL-based):**
- curl-devel, openssl-devel
- perl-IPC-Cmd, libtool
- For TLinux 3: gcc-toolset-10

**Linux (Debian-based):**
- build-essential
- libcurl4-openssl-dev, libssl-dev

**macOS:**
- Installed via Homebrew

## CMake Integration

The script generates `CMakeUserPresets.json`:

```json
{
  "version": 3,
  "configurePresets": [
    {
      "name": "default",
      "cacheVariables": {
        "CMAKE_TOOLCHAIN_FILE": "${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake",
        "VCPKG_ROOT": "${VCPKG_ROOT}"
      }
    }
  ]
}
```

This allows CMake to automatically find vcpkg-installed dependencies.

## Environment Variables

After running the script, these variables are set:

```bash
export VCPKG_ROOT=~/vcpkg  # or your custom path
export PATH=$VCPKG_ROOT:$PATH
```

The script automatically adds them to your shell profile (`~/.bashrc` or `~/.zshrc`).

## Troubleshooting

### vcpkg bootstrap fails

```bash
# Check if C++ compiler is installed
gcc --version  # or clang --version

# Manual bootstrap
cd ~/vcpkg
./bootstrap-vcpkg.sh -disableMetrics
```

### CMake can't find vcpkg toolchain

```bash
# Ensure VCPKG_ROOT is set
export VCPKG_ROOT=~/vcpkg
source ~/.bashrc  # or ~/.zshrc

# Or specify directly
cmake -DCMAKE_TOOLCHAIN_FILE=~/vcpkg/scripts/buildsystems/vcpkg.cmake -B build
```

### Permission denied

```bash
# Make script executable
chmod +x setup_vcpkg_project.sh

# Verify sudo access
sudo -v
```

### Homebrew not found (macOS)

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### TLinux 3 specific issues

```bash
# Enable gcc-toolset-10
source scl_source enable gcc-toolset-10

# Add to ~/.bashrc for persistence
echo "source scl_source enable gcc-toolset-10" >> ~/.bashrc
```

## Advanced Usage

### Custom Overlay Ports

For customizing vcpkg ports:

1. **Create overlay directory:**
   ```bash
   mkdir -p overlay
   ```

2. **Copy and modify a port:**
   ```bash
   cp -r $VCPKG_ROOT/ports/mylib overlay/mylib
   # Edit overlay/mylib/portfile.cmake
   ```

3. **Update vcpkg-configuration.json:**
   ```json
   {
     "overlay-ports": ["./overlay"]
   }
   ```

### Custom Triplets

For custom build configurations:

1. **Create triplets directory:**
   ```bash
   mkdir -p triplets
   ```

2. **Create custom triplet (e.g., `x64-linux-custom.cmake`):**
   ```cmake
   set(VCPKG_TARGET_ARCHITECTURE x64)
   set(VCPKG_CRT_LINKAGE dynamic)
   set(VCPKG_LIBRARY_LINKAGE static)
   ```

3. **Update vcpkg-configuration.json:**
   ```json
   {
     "overlay-triplets": ["./triplets"]
   }
   ```

4. **Use in build:**
   ```bash
   vcpkg install --triplet=x64-linux-custom
   ```

## References

- [vcpkg Official Documentation](https://vcpkg.io/)
- [CMake Presets Documentation](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html)
- [vcpkg GitHub Repository](https://github.com/microsoft/vcpkg)

## License

MIT License - Feel free to use and modify for your projects.
