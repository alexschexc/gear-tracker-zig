# GearTracker

A privacy-focused, offline-only gear management application for firearms enthusiasts, written in Zig.

## Project Status: Beta RC

**Version:** v0.1.3-alpha

GearTracker (Zig) is a rewrite of the original Python application, built with modern technologies for better performance and cross-platform support. The application stores all data locally in SQLite, ensuring complete privacy - no accounts, no cloud sync, no telemetry.

**Platform Support:**

- Linux (Currently Supported)
- Windows (Cross-compilation verification pending)
- macOS (Cross-compilation verification pending)

## Quick Start

### Prerequisites

- Zig 0.15.x
- SQLite3 development libraries
- OpenGL development libraries
- GLFW development libraries

### Build & Run

```bash
# Clone the repository
git clone https://github.com/alexschexc/gear-tracker.git
cd gearTracker-zig

# Build the application
zig build

# Run the application
./zig-out/bin/gearTracker_zig
```

## Features

GearTracker provides comprehensive gear management with 11 main tabs:

### Core Inventory Management

**Firearms Tab**
- Complete firearm inventory with maintenance tracking
- Round count tracking per firearm
- Automatic maintenance reminders based on rounds fired and time
- Maintenance logging with multiple event types
- Transfer/sell functionality with buyer documentation

**NFA Items Tab**
- NFA item management (suppressors, SBRs, SBSs, etc.)
- Tax stamp ID tracking
- Form type recording (Form 1, Form 4, etc.)
- Trust name association
- Maintenance tracking for NFA items

**Attachments Tab**
- Optics, lights, stocks, rails, triggers management
- Track which firearm each attachment is mounted on
- Zero data tracking (distance, notes)
- Mount position tracking

**Soft Gear Tab**
- Armor, vests, backpacks, boots tracking
- Category-based organization
- Maintenance logging

### Reloading

**Reloading Tab**
- Complete reload batch tracking
- Component-level data (bullet, powder, primer, case)
- Test results logging (velocity, ES, SD, group size)
- Batch status tracking (Workup/Approved/Rejected)
- Duplicate batch functionality

### Consumables

**Consumables Tab**
- Ammo, batteries, medical supplies tracking
- Category-based organization (AMMO, BATTERIES, HYGIENE, MEDICAL, CLEANING)
- Low stock alerts when quantity drops below threshold
- Stock transaction history (add/use operations)

### Loadouts

**Loadouts Tab**
- Pre-configured gear sets for specific activities
- Checkout validation:
  - Validates all items are available
  - Checks maintenance status before allowing checkout
  - Validates consumable stock levels
- One-click loadout return with automatic round count logging
- Duplicate loadouts for quick setup

### Checkouts

**Checkouts Tab**
- Item-level checkout for firearms, soft gear, and NFA items
- Borrower management with contact info
- Automatic status updates when items are checked out/returned
- Checkout history with return dates

### Transfers

**Transfers Tab**
- Complete sale documentation
- Buyer information (name, address, DL#, LTC#)
- FFL dealer records
- Sale price tracking
- Automatic firearm status updates

### Import/Export

**Import/Export Tab**
- CSV export (per category or all data)
- CSV import (coming soon)
- Template generation for manual data entry

**Note:** Full CSV import functionality is planned for a future update. Currently, you can export your data to CSV. For migration from the Python version, use the Python application's export feature and re-enter data manually, or copy the SQLite database directly.

## Technology Stack

- **Language:** Zig 0.15.x
- **GUI Framework:** zgui (Dear ImGui) with OpenGL backend
- **Windowing:** zglfw (GLFW bindings)
- **Database:** SQLite3 (via C FFI)
- **Build System:** Zig build system

### Dependencies

- OpenGL headers/libraries
- GLFW headers/libraries
- SQLite3 development libraries
- C standard library

## Data Storage & Privacy

GearTracker stores all data in a single local SQLite database file. By default, the database is created at:

- Linux/macOS: `~/.gear_tracker/tracker.db`
- Windows: `C:\Users\<username>\.gear_tracker\tracker.db`

**No data is ever sent to any remote server.** The developer does not operate any backend service and never has access to your inventory, NFA records, or logs.

If you want additional protection, you can move the `.gear_tracker` folder onto an encrypted volume (e.g., LUKS, VeraCrypt, BitLocker, FileVault) and then symlink it back into your home directory.

**Backups:** To back up your data, close GearTracker and copy `tracker.db` to a safe location:

```bash
cp ~/.gear_tracker/tracker.db ~/.gear_tracker/tracker.db.backup
```

## Migration from Python Version

To migrate from the Python version (v0.1.x-alpha):

1. **Export from Python version:**
   - Open Python GearTracker
   - Go to Import/Export tab
   - Click "Export All to CSV"

2. **Import to Zig version:**
   - *Note: Full CSV import is not yet implemented in the Zig version*
   - Manual options:
     - Copy `tracker.db` directly (same schema)
     - Re-enter data manually
   - Full import functionality coming soon

## Cross-Compilation

Cross-compilation to Windows and macOS is planned but not yet verified. The build system uses zglfw which has platform-specific dependencies.

| Platform | Build Status | Notes |
|----------|--------------|-------|
| Linux | ✅ Working | Native development platform |
| Windows | ⏳ Pending | Requires testing |
| macOS | ⏳ Pending | Requires testing |

## Version History

### v0.1.3-alpha (Current)

**Changes:**
- Complete rewrite in Zig for improved performance
- Feature parity with Python v0.1.2-alpha
- 11-tab GUI interface using zgui
- SQLite database storage

**Completed Features:**
- Full inventory management (firearms, soft gear, NFA items, attachments, consumables)
- Reload/handload tracking with batch management
- Round count tracking per firearm with maintenance thresholds
- Comprehensive maintenance logging
- Borrower management
- Item-level checkout and return system
- Loadout system
- Private sales/transfer tracking
- CSV export functionality
- Complete offline data storage

### v0.1.0 - v0.1.2-alpha (Python Version)

Original Python implementation with PyQt6 UI.

## Building from Source

### Linux (Debian/Ubuntu)

```bash
# Install dependencies
sudo apt-get install build-essential zig sqlite3 libsqlite3-dev libglfw-dev libgl1-mesa-dev

# Build
zig build

# Run
./zig-out/bin/gearTracker_zig
```

### Linux (Fedora/RHEL)

```bash
# Install dependencies
sudo dnf install zig sqlite-devel glfw-devel mesa-libGL-devel

# Build
zig build

# Run
./zig-out/bin/gearTracker_zig
```

### macOS

```bash
# Install dependencies (using Homebrew)
brew install zig sqlite glfw

# Build
zig build

# Run
./zig-out/bin/gearTracker_zig
```

### Windows

Windows cross-compilation requires MinGW-w64 or Windows SDK. Native Windows builds will be available in future releases.

## Project Structure

```
gearTracker-zig/
├── src/
│   ├── main.zig          # Main application and UI
│   ├── root.zig          # Module exports
│   ├── models/           # Data models
│   │   ├── types.zig     # Enums and types
│   │   ├── firearm.zig   # Firearm model
│   │   ├── gear.zig      # Soft gear, NFA, attachments
│   │   ├── consumable.zig
│   │   ├── loadout.zig
│   │   ├── checkout.zig
│   │   ├── maintenance.zig
│   │   └── reloading.zig
│   ├── repository/
│   │   └── database.zig  # SQLite repository
│   └── services/
│       ├── checkout.zig
│       ├── maintenance.zig
│       └── loadout.zig
├── vendor/               # Dependencies
│   ├── zgui/
│   ├── zglfw/
│   └── zopengl/
├── build.zig            # Build configuration
├── build.zig.zon        # Package manifest
└── README.md
```

## Contributing

Contributions are welcome. Please ensure:

1. Code follows Zig style conventions
2. Changes compile without warnings
3. New features include appropriate tests

## License

See LICENSE file for details.

## Support

For issues, feature requests, or questions:
- Open an issue on GitHub
- Contact through provided channels

---

**Note:** This is beta software. While functional, some features may be improved before the 1.0 release. Cross-compilation to Windows and macOS is pending verification before the first stable beta release.
