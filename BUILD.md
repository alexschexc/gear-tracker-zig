# Building GearTracker (Zig Version)

This document provides detailed build instructions for GearTracker on various platforms.

## Prerequisites

- **Zig 0.15.x** - The Zig compiler
- **SQLite3** - Database library
- **GLFW** - Windowing library
- **OpenGL** - Graphics library
- **C Standard Library** - Required by Zig

## Quick Start

```bash
# Clone and enter directory
git clone https://github.com/alexschexc/gear-tracker.git
cd gearTracker-zig

# Build
zig build

# Run
./zig-out/bin/gearTracker_zig

# Install (optional)
zig build install
```

## Platform-Specific Instructions

### Linux

#### Debian/Ubuntu

```bash
# Install build tools and dependencies
sudo apt-get update
sudo apt-get install -y build-essential zig sqlite3 libsqlite3-dev libglfw-dev libgl1-mesa-dev

# Clone the repository
git clone https://github.com/alexschexc/gear-tracker.git
cd gearTracker-zig

# Build the project
zig build
```

#### Fedora/RHEL

```bash
# Install dependencies
sudo dnf install -y zig sqlite-devel glfw-devel mesa-libGL-devel

# Clone and build
git clone https://github.com/alexschexc/gear-tracker.git
cd gearTracker-zig
zig build
```

#### Arch Linux

```bash
# Install dependencies
sudo pacman -S zig sqlite glfw-wayland glfw-x11 mesa

# Clone and build
git clone https://github.com/alexschexc/gear-tracker.git
cd gearTracker-zig
zig build
```

### macOS

```bash
# Install dependencies using Homebrew
brew install zig sqlite glfw

# Clone and build
git clone https://github.com/alexschexc/gear-tracker.git
cd gearTracker-zig
zig build
```

### Windows

Windows support requires cross-compilation or native Windows development.

#### Option 1: Cross-Compilation (Linux → Windows)

```bash
# Install MinGW-w64
sudo apt-get install mingw-w64

# Cross-compile for Windows
zig build -Dtarget=x86_64-windows-gnu

# Output will be in zig-out/bin/gearTracker_zig.exe
```

#### Option 2: Native Windows Development

On Windows, install Zig and the required libraries:

1. Download Zig from https://ziglang.org/download/
2. Install SQLite3 (precompiled binaries)
3. Install GLFW (precompiled binaries)
4. Build:
```powershell
zig build
```

## Build Options

### Build Modes

```bash
# Debug build (default)
zig build

# Release build (optimized)
zig build -Doptimize=ReleaseSafe
zig build -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseSmall
```

### Target Options

```bash
# Native build (your current platform)
zig build

# Cross-compilation examples
zig build -Dtarget=aarch64-linux-gnu    # ARM Linux
zig build -Dtarget=x86_64-windows-gnu  # Windows
zig build -Dtarget=aarch64-macos        # macOS ARM
```

## Running the Application

After building:

```bash
# Run directly from build output
./zig-out/bin/gearTracker_zig

# Or install and run
zig build install
./zig-out/bin/gearTracker_zig
```

## Development

### Running Tests

```bash
zig test
```

### Code Formatting

```bash
zig fmt src/
```

### Dependencies

The project uses vendored dependencies in the `vendor/` directory:

- **zgui** - Dear ImGui bindings
- **zglfw** - GLFW bindings  
- **zopengl** - OpenGL bindings

These are included as git submodules or local copies and don't need separate installation.

## Troubleshooting

### "zglfw not found"

Ensure you have GLFW development libraries installed:

- Debian/Ubuntu: `sudo apt-get install libglfw-dev`
- Fedora: `sudo dnf install glfw-devel`
- macOS: `brew install glfw`

### "libGL not found"

Install OpenGL development libraries:

- Debian/Ubuntu: `sudo apt-get install libgl1-mesa-dev`
- Fedora: `sudo dnf install mesa-libGL-devel`
- macOS: Included with Xcode

### "sqlite3 not found"

Install SQLite development libraries:

- Debian/Ubuntu: `sudo apt-get install libsqlite3-dev`
- Fedora: `sudo dnf install sqlite-devel`
- macOS: `brew install sqlite`

### Build Errors

If you encounter build errors, try:

```bash
# Clean and rebuild
rm -rf zig-cache zig-out
zig build
```

## Cross-Compilation Status

| Target | Status | Notes |
|--------|--------|-------|
| x86_64-linux | ✅ Working | Native dev platform |
| aarch64-linux | ⏳ Untested | Should work |
| x86_64-windows-gnu | ⏳ Pending | Needs testing |
| aarch64-macos | ⏳ Pending | Needs testing |
| x86_64-macos | ⏳ Pending | Needs testing |

## Version Information

- **Package Version:** 0.1.3
- **Zig Version:** 0.15.x required
- **Target SQLite:** 3.x

## License

See LICENSE file in project root.
