# Zed Editor C++ Development Configuration Guide

This document provides detailed instructions on configuring Zed editor for C++ development, including clangd LSP configuration and debugging setup.

## Table of Contents

- [Configuration File Locations](#configuration-file-locations)
- [Clangd LSP Configuration](#clangd-lsp-configuration)
- [C++ Debugging Configuration](#c-debugging-configuration)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Additional Settings](#additional-settings)

---

## Configuration File Locations

Zed configuration files are typically located at:
- **Linux/WSL**: `~/.config/zed/settings.json` and `~/.config/zed/keymap.json`
- **macOS**: `~/Library/Application Support/Zed/settings.json` and `~/Library/Application Support/Zed/keymap.json`
- **Windows**: `%APPDATA%\Zed\settings.json` and `%APPDATA%\Zed\keymap.json`

### How to Configure Zed

#### Method 1: Through Command Palette (Recommended)

1. Open command palette with `Ctrl+Shift+P` (Linux/Windows) or `Cmd+Shift+P` (macOS)
2. Execute the following commands:
   - `zed: open settings` - Open your user settings
   - `zed: open default settings` - View default settings (read-only)
   - `zed: open keymap` - Open your keybindings
   - `zed: open default keymap` - View default keybindings (read-only)

#### Method 2: Manual File Editing

Copy the configuration files from this directory to your Zed config directory:

**Linux/WSL:**
```bash
cp settings.json ~/.config/zed/settings.json
cp keymap.json ~/.config/zed/keymap.json
```

**macOS:**
```bash
cp settings.json ~/Library/Application\ Support/Zed/settings.json
cp keymap.json ~/Library/Application\ Support/Zed/keymap.json
```

**Windows (PowerShell):**
```powershell
Copy-Item settings.json $env:APPDATA\Zed\settings.json
Copy-Item keymap.json $env:APPDATA\Zed\keymap.json
```

#### Method 3: Using Symbolic Links (Advanced)

For easier configuration management, you can create symbolic links:

**Linux/WSL:**
```bash
ln -sf $(pwd)/settings.json ~/.config/zed/settings.json
ln -sf $(pwd)/keymap.json ~/.config/zed/keymap.json
```

**macOS:**
```bash
ln -sf $(pwd)/settings.json ~/Library/Application\ Support/Zed/settings.json
ln -sf $(pwd)/keymap.json ~/Library/Application\ Support/Zed/keymap.json
```

⚠️ **Note**: After modifying configuration files, you may need to:
- Restart Zed completely, or
- Execute `zed: reload window` from the command palette

---

## Clangd LSP Configuration

### 1. Install Clangd

Ensure clangd is installed on your system. This configuration uses LLVM 20:

```bash
# Ubuntu/Debian
sudo apt install clangd-20

# Or download from LLVM official website
# https://releases.llvm.org/
```

### 2. Clangd Configuration in settings.json

Configure clangd in `settings.json`:

```json
{
  "lsp": {
    "clangd": {
      "binary": {
        "path": "/usr/lib/llvm-20/bin/clangd",
        "arguments": [
          "--header-insertion=never",
          "--compile-commands-dir=${workspaceFolder}/build",
          "--background-index",
          "--completion-style=detailed"
        ]
      }
    }
  }
}
```

#### Configuration Parameters Explained:

- **`path`**: Full path to the clangd binary
- **`--header-insertion=never`**: Disable automatic header insertion
- **`--compile-commands-dir=${workspaceFolder}/build`**: Specify the directory containing `compile_commands.json`
  - `${workspaceFolder}` will be replaced with the current workspace root directory
  - Here it's set to the `build` directory
- **`--background-index`**: Enable background indexing for better completion and navigation performance
- **`--completion-style=detailed`**: Use detailed code completion style

### 3. Generating compile_commands.json

Clangd relies on the `compile_commands.json` file to understand project structure and compilation options.

#### Method 1: CMake Projects

Add to your `CMakeLists.txt`:

```cmake
# Add this to your top-level CMakeLists.txt
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
```

Then build the project:

```bash
mkdir -p build
cd build
cmake ..
make
```

This will generate `compile_commands.json` in the `build` directory.

#### Method 2: Other Build Systems

- **Bear**: For Make and other build systems
  ```bash
  bear -- make
  ```

- **Ninja**: Automatically generates `compile_commands.json`
  ```bash
  cmake -GNinja ..
  ninja
  ```

### 4. Important Notes

⚠️ **Critical Points**:

1. **Keep compile_commands.json Updated**
   - Regenerate after modifying CMakeLists.txt or adding new files
   - Otherwise, clangd may not recognize new source files or configurations

2. **Directory Structure Requirements**
   - Ensure `compile_commands.json` is in the configured `build` directory
   - If using a different build directory, update the `--compile-commands-dir` parameter

3. **Verify Clangd is Working**
   - After opening a C++ file, check the status bar for clangd connection status
   - Test code completion, go-to-definition, and other features

---

## C++ Debugging Configuration

Zed supports C++ debugging through the **Debug Adapter Protocol (DAP)** using LLDB or GDB as the backend debugger.

### 1. Prerequisites

#### Install Debugger

**Linux/WSL:**
```bash
# Install LLDB (recommended)
sudo apt install lldb

# Or install GDB
sudo apt install gdb
```

**macOS:**
```bash
# LLDB comes pre-installed with Xcode Command Line Tools
xcode-select --install

# Or install via Homebrew
brew install llvm
```

**Windows:**
- Install MSVC with Visual Studio (includes debugger)
- Or install LLDB from LLVM: https://releases.llvm.org/

#### Compile with Debug Symbols

Ensure your project is compiled in Debug mode:

**CMake:**
```cmake
# CMakeLists.txt - Method 1: Set build type in CMakeLists.txt
set(CMAKE_BUILD_TYPE Debug)

# Method 2: Specify during configuration
# cmake -DCMAKE_BUILD_TYPE=Debug ..

# Ensure debug symbols and disable optimizations
set(CMAKE_CXX_FLAGS_DEBUG "-g -O0")
```

**Makefile:**
```makefile
CXXFLAGS = -g -O0 -std=c++17
```

**Verify debug symbols:**
```bash
file build/your_executable
# Should show "not stripped" or "with debug_info"

# Or use objdump
objdump -h build/your_executable | grep debug
```

---

### 2. Configure Debugger in Zed

Zed uses **tasks** to define debug configurations. Create a tasks configuration file.

#### Option A: Project-Level Configuration (Recommended)

Create `.zed/tasks.json` in your project root:

```json
[
  {
    "label": "Debug C++ Application",
    "command": "lldb-dap",
    "args": ["--port", "12345"],
    "use_new_terminal": true,
    "reveal": "always"
  }
]
```

#### Option B: Global Configuration

Add to `~/.config/zed/settings.json`:

```json
{
  "task": {
    "default": {
      "env": {
        "LLDB_DEBUGSERVER_PATH": "/usr/bin/lldb-server"
      }
    }
  },
  "terminal": {
    "shell": {
      "program": "/bin/bash"
    }
  }
}
```

---

### 3. How to Debug in Zed

#### Method 1: Using Built-in Debug Panel

1. **Open your C++ source file**

2. **Set breakpoints:**
   - Click on the line number gutter (left margin)
   - A red dot will appear indicating the breakpoint
   - Or place cursor on line and press `F9`

3. **Start debugging:**
   - Press `F5`, or
   - Open command palette (`Ctrl+Shift+P`) → `Debug: Start Debugging`
   - Select the debug configuration

4. **Debug controls:**
   - **Continue** (`F5`): Resume execution until next breakpoint
   - **Step Over** (`F10`): Execute current line, don't enter functions
   - **Step Into** (`F11`): Step into function calls
   - **Step Out** (`Shift+F11`): Complete current function and return
   - **Stop** (`Shift+F5`): Terminate debugging session

5. **Inspect variables:**
   - Hover over variables to see their values
   - Use the Variables panel in the debug sidebar
   - Use the Watch panel to monitor specific expressions

#### Method 2: Attach to Running Process

1. **Start your application:**
   ```bash
   ./build/your_executable &
   ```

2. **Find the process ID:**
   ```bash
   pgrep your_executable
   # Or
   ps aux | grep your_executable
   ```

3. **Attach debugger:**
   - Command palette → `Debug: Attach to Process`
   - Enter PID or select from the process list

4. **Set breakpoints and debug normally**

#### Method 3: Using Terminal with LLDB Directly

For advanced debugging scenarios:

```bash
# Start LLDB with your executable
lldb ./build/your_executable

# Inside LLDB:
(lldb) breakpoint set --name main
(lldb) breakpoint set --file main.cpp --line 42
(lldb) run
(lldb) next        # Step over
(lldb) step        # Step into
(lldb) continue    # Continue execution
(lldb) print var   # Print variable value
(lldb) bt          # Backtrace
(lldb) quit
```

---

### 4. Advanced Debug Configuration

#### Configure LLDB Path

In `settings.json`:

```json
{
  "lsp": {
    "lldb": {
      "binary": {
        "path": "/usr/bin/lldb",
        "arguments": []
      }
    }
  }
}
```

#### Debug with Arguments

Create `.zed/tasks.json`:

```json
[
  {
    "label": "Debug with Arguments",
    "command": "lldb",
    "args": [
      "-o", "run",
      "--",
      "${workspaceFolder}/build/your_executable",
      "--input", "data.txt",
      "--verbose"
    ],
    "use_new_terminal": true
  }
]
```

#### Debug with Environment Variables

```json
[
  {
    "label": "Debug with Env",
    "command": "${workspaceFolder}/build/your_executable",
    "env": {
      "DEBUG": "1",
      "LOG_LEVEL": "trace",
      "LD_LIBRARY_PATH": "/custom/lib/path"
    },
    "use_new_terminal": true
  }
]
```

---

### 5. Debugging Shortcuts Reference

| Shortcut | Action | Description |
|----------|--------|-------------|
| `F5` | Start/Continue | Start debugging or continue execution |
| `F9` | Toggle Breakpoint | Add/remove breakpoint at current line |
| `F10` | Step Over | Execute current line without entering functions |
| `F11` | Step Into | Step into function calls |
| `Shift+F11` | Step Out | Complete current function and return to caller |
| `Shift+F5` | Stop Debugging | Terminate the debug session |
| `Ctrl+Shift+F5` | Restart | Restart the debugging session |

---

### 6. Debug Panel Features

The debug panel in Zed provides:

1. **Variables View**
   - Local variables and their values
   - Function arguments
   - Global variables in scope

2. **Watch Expressions**
   - Add custom expressions to monitor
   - Automatically updated on each step

3. **Call Stack**
   - View the current execution stack
   - Navigate to different stack frames

4. **Breakpoints Panel**
   - List all breakpoints
   - Enable/disable breakpoints
   - Add conditional breakpoints

5. **Debug Console**
   - Execute debugger commands directly
   - Evaluate expressions in current context

---

### 7. Common Debugging Scenarios

#### Debugging Multi-threaded Applications

```json
{
  "label": "Debug Multithreaded",
  "command": "lldb",
  "args": [
    "-o", "settings set target.process.stop-on-exec false",
    "-o", "run",
    "${workspaceFolder}/build/your_executable"
  ]
}
```

**LLDB thread commands:**
```lldb
(lldb) thread list              # List all threads
(lldb) thread select 2          # Switch to thread 2
(lldb) thread backtrace all     # Show backtrace for all threads
```

#### Debugging Crashes (Core Dumps)

```bash
# Enable core dumps
ulimit -c unlimited

# Run program (it will crash and generate core)
./build/your_executable

# Debug with core dump
lldb ./build/your_executable -c core
(lldb) bt                       # Show backtrace at crash
(lldb) frame select 0           # Select crash frame
(lldb) print variable_name      # Inspect variables
```

#### Conditional Breakpoints

In Zed debug console:
```lldb
breakpoint set --name functionName --condition 'variable == 42'
breakpoint set --file main.cpp --line 100 --condition 'count > 1000'
```

#### Memory Debugging

```lldb
(lldb) memory read 0x12345678        # Read memory at address
(lldb) memory write 0x12345678 0xFF  # Write to memory
(lldb) watchpoint set variable var   # Break when variable changes
```

---

### 8. Troubleshooting Debug Issues

#### Issue: "Debug symbols not found"

**Solution:**
```bash
# Verify debug symbols exist
file build/your_executable
objdump -g build/your_executable

# Rebuild with debug flags
cmake -DCMAKE_BUILD_TYPE=Debug ..
make clean && make
```

#### Issue: "Cannot attach to process"

**Solution:**
```bash
# Linux: Disable ptrace restrictions (use with caution)
echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope

# Or run debugger with sudo (not recommended)
sudo lldb
```

#### Issue: "Breakpoints not being hit"

**Checklist:**
1. Verify the code is actually being executed
2. Ensure you're debugging the correct binary
3. Check that debug symbols are present
4. Disable compiler optimizations (`-O0`)
5. Verify the source file path matches

```bash
# In LLDB, check if breakpoint is resolved
(lldb) breakpoint list
# Should show "resolved" status
```

#### Issue: "Step Into not working for standard library"

**Solution:**
```lldb
# Enable stepping into system libraries
(lldb) settings set target.process.thread.step-avoid-regexp ""
```

---

### 9. Integration with External Tools

#### Debugging with Valgrind

```bash
# Find memory leaks
valgrind --leak-check=full ./build/your_executable

# Debug with Valgrind + LLDB
valgrind --vgdb=yes --vgdb-error=0 ./build/your_executable
# In another terminal:
lldb
(lldb) process connect --plugin gdb-remote localhost:1234
```

#### Using AddressSanitizer (ASan)

```cmake
# CMakeLists.txt
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=address -g")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=address")
```

```bash
# Run with ASan
./build/your_executable
# ASan will automatically report memory errors
```

---

## Keyboard Shortcuts

This configuration includes the following custom shortcuts (see `keymap.json`):

### Navigation Shortcuts

- **`Shift Shift`**: Open file finder (similar to IntelliJ IDEA)
- **`Ctrl+H`**: Toggle focus to project panel
- **`Ctrl+L`**: Toggle focus to AI Agent panel
- **`Ctrl+J`**: Toggle bottom dock (terminal/problems/output)

### Vim Mode Shortcuts

- **`j k`** (in Insert mode): Quickly return to Normal mode
- **`Ctrl+C`**: Copy (overrides Vim default behavior)
- **`Ctrl+V`**: Paste (overrides Vim default behavior)

### Keybinding Explanation

```json
{
  "context": "Editor && vim_mode == insert",
  "bindings": {
    "j k": "vim::NormalBefore"  // Press j k quickly in insert mode to return to normal mode
  }
}
```

---

## Additional Settings

### Language-Specific Configuration

```json
{
  "languages": {
    "C++": {
      "format_on_save": "on",  // Auto-format on save
      "tab_size": 2            // Indent size of 2 spaces
    }
  }
}
```

### Theme Configuration

```json
{
  "theme": {
    "mode": "system",      // Follow system theme
    "light": "Ayu Dark",   // Light mode theme
    "dark": "One Dark"     // Dark mode theme
  }
}
```

### Vim Mode

```json
{
  "vim_mode": true  // Enable Vim mode
}
```

### Font Sizes

```json
{
  "ui_font_size": 16,      // UI font size
  "buffer_font_size": 15   // Editor font size
}
```

### WSL Integration

```json
{
  "wsl_connections": [
    {
      "distro_name": "Ubuntu",
      "user": null,
      "projects": [
        {
          "paths": ["/home/ts_user"]
        }
      ]
    }
  ]
}
```

### AI Agent Configuration

```json
{
  "agent": {
    "default_model": {
      "provider": "zed.dev",
      "model": "grok-4"
    }
  }
}
```

---

## Troubleshooting

### Clangd Not Working

1. **Check clangd path**:
   ```bash
   which clangd
   /usr/lib/llvm-20/bin/clangd --version
   ```

2. **Verify compile_commands.json exists**:
   ```bash
   ls -la build/compile_commands.json
   ```

3. **Check Zed logs**:
   - Command palette: `zed: open logs`
   - Look for clangd-related error messages

4. **Restart LSP server**:
   - Command palette: `zed: restart language server`

### Debugging Won't Start

1. **Confirm executable path is correct**
2. **Check for debug symbols**:
   ```bash
   file build/your_executable
   # Should contain "not stripped" or "with debug_info"
   ```

3. **Verify debugger installation**:
   ```bash
   lldb --version
   # or
   gdb --version
   ```

---

## References

- [Zed Official Documentation](https://zed.dev/docs)
- [Clangd Documentation](https://clangd.llvm.org/)
- [CMake Documentation](https://cmake.org/documentation/)
- [LLDB Tutorial](https://lldb.llvm.org/use/tutorial.html)

---

## Quick Start

### Initial Setup

1. **Copy configuration files:**
   ```bash
   cp settings.json ~/.config/zed/settings.json
   cp keymap.json ~/.config/zed/keymap.json
   ```

2. **Verify clangd installation:**
   ```bash
   which clangd
   # or
   clangd --version
   ```

3. **Enable compile_commands.json in your project:**
   ```cmake
   # Add to CMakeLists.txt
   set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
   ```

4. **Build your project:**
   ```bash
   mkdir -p build && cd build
   cmake -DCMAKE_BUILD_TYPE=Debug ..
   make
   ```

5. **Restart Zed:**
   - Close and reopen Zed, or
   - Command palette → `zed: reload window`

### Quick Debug Test

1. **Open a C++ file in Zed**

2. **Click on line number to set a breakpoint**

3. **Press `F5` to start debugging**

4. **Use debug shortcuts:**
   - `F10` - Step over
   - `F11` - Step into
   - `Shift+F5` - Stop debugging

### Configuration Summary

This setup provides:
- ✅ **LSP Support**: Clangd with compile commands
- ✅ **Vim Mode**: With `jk` to exit insert mode
- ✅ **Debug Support**: LLDB integration
- ✅ **Custom Shortcuts**: File finder, panel navigation
- ✅ **Auto-formatting**: Format on save for C++
- ✅ **WSL Support**: Configured for Ubuntu WSL
- ✅ **AI Agent**: Grok-4 model integration

---

**Version Information**:
- Zed: Latest version
- Clangd: LLVM 20
- Operating System: Linux/WSL Ubuntu
