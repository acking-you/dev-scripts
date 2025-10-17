#!/bin/bash
# One-click setup script for vcpkg-based C++ projects
# This script automates the setup of development environment including:
# - System dependencies installation
# - vcpkg installation and configuration
# - CMake presets generation

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
Usage: $0 [OPTIONS]

One-click setup script for vcpkg-based C++ projects

OPTIONS:
    --help                      Show this help message
    --vcpkg-root=PATH          Specify vcpkg installation path (default: ~/vcpkg)
    --skip-system-deps         Skip system dependencies installation
    --skip-vcpkg-install       Skip vcpkg installation (use existing)
    --force-reinstall          Force reinstall vcpkg even if it exists
    --with-cmake-preset        Generate CMakeUserPresets.json
    --preset-template=PATH     Path to CMakeUserPresets.json.template

EXAMPLES:
    # Basic setup with default vcpkg location
    $0

    # Setup with custom vcpkg location
    $0 --vcpkg-root=/opt/vcpkg

    # Setup with CMake preset generation
    $0 --with-cmake-preset --preset-template=./CMakeUserPresets.json.template

    # Skip system dependencies (already installed)
    $0 --skip-system-deps

EOF
}

# Default values
VCPKG_ROOT="${HOME}/vcpkg"
SKIP_SYSTEM_DEPS=false
SKIP_VCPKG_INSTALL=false
FORCE_REINSTALL=false
WITH_CMAKE_PRESET=false
PRESET_TEMPLATE=""

# Parse arguments
for arg in "$@"; do
    case $arg in
        --help)
            show_usage
            exit 0
            ;;
        --vcpkg-root=*)
            VCPKG_ROOT="${arg#*=}"
            ;;
        --skip-system-deps)
            SKIP_SYSTEM_DEPS=true
            ;;
        --skip-vcpkg-install)
            SKIP_VCPKG_INSTALL=true
            ;;
        --force-reinstall)
            FORCE_REINSTALL=true
            ;;
        --with-cmake-preset)
            WITH_CMAKE_PRESET=true
            ;;
        --preset-template=*)
            PRESET_TEMPLATE="${arg#*=}"
            WITH_CMAKE_PRESET=true
            ;;
        *)
            print_error "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Detect OS and distribution
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            OS_NAME=$ID
            OS_VERSION=$VERSION_ID
        else
            OS_NAME="unknown"
            OS_VERSION="unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_NAME="macos"
        OS_VERSION=$(sw_vers -productVersion)
    else
        OS_NAME="unknown"
        OS_VERSION="unknown"
    fi

    print_info "Detected OS: $OS_NAME $OS_VERSION"
}

# Install system dependencies for Linux
install_linux_deps() {
    print_info "Installing system dependencies for Linux..."

    local packages=""

    # Common packages for most distributions
    if [[ "$OS_NAME" == "centos" ]] || [[ "$OS_NAME" == "rhel" ]] || [[ "$OS_NAME" == "tlinux" ]] || grep -q "TencentOS" /etc/os-release 2>/dev/null; then
        # RHEL-based distributions (CentOS, RHEL, TencentOS)
        packages="
            git
            cmake
            gcc
            g++
            curl-devel
            perl-IPC-Cmd
            libtool
            openssl-devel
            python3-pip
            ccache
            ninja-build
            wget
            tar
            zip
            unzip
        "

        # Check TencentOS/TLinux version
        if grep -q "TencentOS" /etc/os-release 2>/dev/null; then
            version_id=$(grep VERSION_ID /etc/os-release | cut -d'=' -f2 | tr -d '"')
            major_version=$(echo "$version_id" | cut -d'.' -f1)

            if [[ "$major_version" == "3" ]]; then
                packages+=" gcc-toolset-10 gcc-toolset-10-libasan-devel"
            fi
        fi

        print_info "Installing packages with dnf/yum..."
        if command -v dnf &> /dev/null; then
            sudo dnf install -y $packages
        else
            sudo yum install -y $packages
        fi

    elif [[ "$OS_NAME" == "ubuntu" ]] || [[ "$OS_NAME" == "debian" ]]; then
        # Debian-based distributions
        packages="
            git
            cmake
            build-essential
            curl
            libcurl4-openssl-dev
            pkg-config
            libtool
            libssl-dev
            python3-pip
            ccache
            ninja-build
            wget
            tar
            zip
            unzip
        "

        print_info "Updating package list..."
        sudo apt-get update

        print_info "Installing packages with apt..."
        sudo apt-get install -y $packages

    else
        print_warning "Unsupported Linux distribution: $OS_NAME"
        print_warning "Please install dependencies manually:"
        print_warning "  - git, cmake, gcc/g++, curl, openssl, python3, ccache, ninja-build"
        return 1
    fi

    print_success "System dependencies installed successfully"
}

# Install system dependencies for macOS
install_macos_deps() {
    print_info "Installing system dependencies for macOS..."

    if ! command -v brew &> /dev/null; then
        print_error "Homebrew not found. Please install Homebrew first:"
        print_error "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
    fi

    local packages="
        git
        cmake
        ninja
        ccache
        pkg-config
        openssl
    "

    print_info "Installing packages with Homebrew..."
    brew install $packages || true

    print_success "System dependencies installed successfully"
}

# Install system dependencies
install_system_deps() {
    if [[ "$SKIP_SYSTEM_DEPS" == true ]]; then
        print_info "Skipping system dependencies installation"
        return 0
    fi

    detect_os

    if [[ "$OS_NAME" == "macos" ]]; then
        install_macos_deps
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        install_linux_deps
    else
        print_warning "Unsupported operating system: $OSTYPE"
        print_warning "Please install dependencies manually"
        return 1
    fi
}

# Install vcpkg
install_vcpkg() {
    if [[ "$SKIP_VCPKG_INSTALL" == true ]]; then
        print_info "Skipping vcpkg installation"
        return 0
    fi

    VCPKG_ROOT=$(realpath "$VCPKG_ROOT" 2>/dev/null || echo "$VCPKG_ROOT")

    if [[ -d "$VCPKG_ROOT" ]]; then
        if [[ "$FORCE_REINSTALL" == true ]]; then
            print_warning "Removing existing vcpkg installation at $VCPKG_ROOT"
            rm -rf "$VCPKG_ROOT"
        else
            print_info "vcpkg already exists at $VCPKG_ROOT"

            # Check if vcpkg executable exists
            if [[ -x "$VCPKG_ROOT/vcpkg" ]]; then
                print_success "Using existing vcpkg installation"
                return 0
            else
                print_warning "vcpkg directory exists but executable not found"
                print_info "Running bootstrap..."
            fi
        fi
    fi

    if [[ ! -d "$VCPKG_ROOT" ]]; then
        print_info "Cloning vcpkg from GitHub..."
        if ! git clone https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT"; then
            print_error "Failed to clone vcpkg repository"
            return 1
        fi
    fi

    print_info "Bootstrapping vcpkg..."
    cd "$VCPKG_ROOT"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        if ! ./bootstrap-vcpkg.bat -disableMetrics; then
            print_error "Failed to bootstrap vcpkg"
            return 1
        fi
    else
        if ! ./bootstrap-vcpkg.sh -disableMetrics; then
            print_error "Failed to bootstrap vcpkg"
            return 1
        fi
    fi

    print_success "vcpkg installed successfully at $VCPKG_ROOT"
}

# Generate CMakeUserPresets.json
generate_cmake_preset() {
    if [[ "$WITH_CMAKE_PRESET" != true ]]; then
        return 0
    fi

    local output_file="CMakeUserPresets.json"

    print_info "Generating CMake user presets..."

    # If template is provided, use it
    if [[ -n "$PRESET_TEMPLATE" ]] && [[ -f "$PRESET_TEMPLATE" ]]; then
        print_info "Using template: $PRESET_TEMPLATE"
        # Replace VCPKG_ROOT placeholder
        sed "s|\${VCPKG_ROOT}|$VCPKG_ROOT|g" "$PRESET_TEMPLATE" > "$output_file"
        print_success "Generated $output_file from template"
        return 0
    fi

    # Otherwise generate a basic preset
    cat > "$output_file" << EOF
{
  "version": 3,
  "configurePresets": [
    {
      "name": "default",
      "hidden": false,
      "cacheVariables": {
        "CMAKE_TOOLCHAIN_FILE": "$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake",
        "VCPKG_ROOT": "$VCPKG_ROOT"
      }
    }
  ]
}
EOF

    print_success "Generated $output_file"
}

# Add vcpkg to PATH
setup_environment() {
    print_info "Setting up environment variables..."

    local shell_rc=""
    if [[ -n "$BASH_VERSION" ]]; then
        shell_rc="$HOME/.bashrc"
    elif [[ -n "$ZSH_VERSION" ]]; then
        shell_rc="$HOME/.zshrc"
    fi

    if [[ -n "$shell_rc" ]] && [[ -f "$shell_rc" ]]; then
        # Check if VCPKG_ROOT is already in shell rc
        if grep -q "VCPKG_ROOT" "$shell_rc"; then
            print_info "VCPKG_ROOT already configured in $shell_rc"
        else
            print_info "Adding VCPKG_ROOT to $shell_rc"
            cat >> "$shell_rc" << EOF

# vcpkg environment (added by setup_vcpkg_project.sh)
export VCPKG_ROOT="$VCPKG_ROOT"
export PATH="\$VCPKG_ROOT:\$PATH"
EOF
            print_success "Added VCPKG_ROOT to $shell_rc"
            print_warning "Please run: source $shell_rc"
        fi
    fi

    # Set for current session
    export VCPKG_ROOT="$VCPKG_ROOT"
    export PATH="$VCPKG_ROOT:$PATH"
}

# Print summary
print_summary() {
    echo ""
    echo "========================================"
    print_success "Setup completed successfully!"
    echo "========================================"
    echo ""
    print_info "vcpkg location: $VCPKG_ROOT"
    print_info "vcpkg executable: $VCPKG_ROOT/vcpkg"
    echo ""
    print_info "Next steps:"
    echo "  1. Make sure VCPKG_ROOT is set in your environment:"
    echo "     export VCPKG_ROOT=$VCPKG_ROOT"
    echo ""
    echo "  2. If you have a vcpkg.json, install dependencies:"
    echo "     cd <your-project-dir>"
    echo "     $VCPKG_ROOT/vcpkg install"
    echo ""
    echo "  3. Configure your project with CMake:"
    echo "     cmake --preset=default -B build"
    echo "     cmake --build build"
    echo ""

    if [[ -f "vcpkg.json" ]]; then
        print_info "Found vcpkg.json in current directory"
        echo "  You can install dependencies now with:"
        echo "     $VCPKG_ROOT/vcpkg install"
    fi

    if [[ -f "vcpkg-configuration.json" ]]; then
        print_info "Found vcpkg-configuration.json (overlay ports/triplets configured)"
    fi

    echo ""
}

# Main execution
main() {
    print_info "Starting vcpkg-based C++ project setup..."
    echo ""

    # Install system dependencies
    install_system_deps
    echo ""

    # Install vcpkg
    install_vcpkg
    echo ""

    # Generate CMake preset if requested
    generate_cmake_preset
    echo ""

    # Setup environment variables
    setup_environment
    echo ""

    # Print summary
    print_summary
}

# Run main function
main
