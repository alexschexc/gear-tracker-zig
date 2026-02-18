# GearTracker Zig GUI Implementation Plan

## Overview

Port the GearTracker application from Python to Zig with native GUI using zgui (Dear ImGui) with OpenGL backend.

## Environment

### System Dependencies (Already Installed)

| Package | Location |
|---------|----------|
| OpenGL headers | `/usr/include/GL/` |
| GLFW headers | `/usr/include/GLFW/` |
| GLFW library | `/usr/lib/libglfw.so` |
| OpenGL library | `/usr/lib/libGL.so` |

### Zig Version

- **Zig 0.15.2** - Required for zgui
- Managed via `mise local zig@0.15.2`

---

## Phase 1: Remove Capy

### 1.1 Update build.zig.zon

Remove Capy dependency:
```zig
.dependencies = .{
    .zgui = .{ .path = "vendor/zgui" },
    .zglfw = .{ .path = "vendor/zglfw" },
    .zopengl = .{ .path = "vendor/zopengl" },
}
```

### 1.2 Update build.zig

- Remove Capy module imports
- Remove GTK4 linking
- Add zgui, zglfw, zopengl modules
- Link system libraries: `glfw`, `GL`

### 1.3 Remove old main.zig

Backup or delete the Capy-based main.zig

---

## Phase 2: Implementation

### 2.1 Main Structure

```zig
const std = @import("std");
const zglfw = @import("zglfw");
const zgui = @import("zgui");
const gear = @import("gearTracker_zig");

var window: *zglfw.Window = undefined;
var selected_row: ?usize = null;
var current_category: Category = .firearms;
var sort_column: usize = 0;
var sort_ascending: bool = true;

const Category = enum { firearms, softgear, nfa, attachments };
```

### 2.2 Initialization

```zig
pub fn main() !void {
    // 1. Initialize GLFW
    try zglfw.init();
    defer zglfw.terminate();

    // 2. Create window
    window = try zglfw.Window.create(900, 600, "GearTracker", null, null);
    defer window.destroy();

    // 3. Make OpenGL context current
    try window.makeContextCurrent();

    // 4. Initialize zgui
    zgui.init(allocator);

    // 5. Initialize zgui backend (GLFW + OpenGL3)
    zgui.backend.init(window);

    // 6. Load font (optional)
    // _ = zgui.io.addFontFromFile("/path/to/font.ttf", 16.0);

    // 7. Main loop
    while (!window.shouldClose()) {
        zglfw.pollEvents();

        var fb_size = window.getFramebufferSize();
        zgui.backend.newFrame(fb_size[0], fb_size[1]);

        try renderUI();

        zgui.backend.draw();

        window.swapBuffers();
    }
}
```

### 2.3 UI Rendering - Table Implementation

```zig
fn renderUI() !void {
    // Category tabs
    if (zgui.beginTabBar("categories", .{})) {
        if (zgui.tabItemButton("Firearms", .{})) { current_category = .firearms; }
        if (zgui.tabItemButton("Soft Gear", .{})) { current_category = .softgear; }
        if (zgui.tabItemButton("NFA Items", .{})) { current_category = .nfa; }
        if (zgui.tabItemButton("Attachments", .{})) { current_category = .attachments; }
        zgui.endTabBar();
    }

    // Table with 3 columns: Name, Caliber, Serial
    if (zgui.beginTable("gear", 3, .{})) {
        // Headers (clickable for sort)
        zgui.tableSetupColumn("Name", .{}, 0);
        zgui.tableSetupColumn("Caliber", .{}, 1);
        zgui.tableSetupColumn("Serial", .{}, 2);

        // Sort indicators
        zgui.tableHeadersRow();

        // Handle header click for sorting
        if (zgui.tableGetSortColumn() >= 0) {
            sort_column = @intCast(zgui.tableGetSortColumn());
            sort_ascending = !sort_ascending;
            sortData();
        }

        // Load and sort data
        const data = getDataForCategory(current_category);
        const sorted = sortData(data, sort_column, sort_ascending);

        // Render rows
        for (sorted, 0..) |item, i| {
            if (zgui.tableNextRow(.{})) {
                // Selection column
                zgui.tableSetColumnIndex(0);
                const is_selected = (selected_row == i);
                if (zgui.selectable(item.name, is_selected, .{}, .{})) {
                    selected_row = i;
                }

                // Double-click for edit
                if (zgui.isItemHovered() and zgui.isMouseDoubleClicked(.left)) {
                    openEditDialog(item);
                }

                // Other columns
                zgui.tableSetColumnIndex(1);
                zgui.text(item.caliber);
                zgui.tableSetColumnIndex(2);
                zgui.text(item.serial);
            }
        }

        zgui.endTable();
    }
}
```

### 2.4 Data Functions

```zig
fn getDataForCategory(cat: Category) []Item {
    // Fetch from database based on category
    switch (cat) {
        .firearms => { /* return firearm data */ },
        .softgear => { /* return soft gear data */ },
        .nfa => { /* return NFA data */ },
        .attachments => { /* return attachment data */ },
    }
}

fn sortData(data: []Item, col: usize, asc: bool) []Item {
    // Sort in-place or return new slice
}

fn openEditDialog(item: Item) void {
    zgui.openPopup("Edit Item");
    if (zgui.beginPopupModal("Edit Item", .{}, .{})) {
        // Form fields
        // Save/Cancel buttons
        zgui.endPopup();
    }
}
```

---

## Features

### Implemented

1. **Category Tabs**
   - Firearms, Soft Gear, NFA Items, Attachments

2. **Table Display**
   - 3 columns: Name, Caliber, Serial
   - Native zgui table with headers

3. **Sorting**
   - Click column header to sort
   - Toggle ascending/descending

4. **Row Selection**
   - Click to select row
   - Visual highlight on selected row

### Future (Not in Initial Implementation)

5. **Edit Dialog**
   - Modal popup for editing
   - Form fields for each property
   - Save to database

---

## Build Commands

```bash
# Switch to Zig 0.15.2
mise local zig@0.15.2

# Build
zig build

# Run
./zig-out/bin/gearTracker_zig
```

---

## Files

| File | Action |
|------|--------|
| `build.zig.zon` | Update dependencies |
| `build.zig` | Add zgui modules + OpenGL linking |
| `src/main.zig` | Rewrite with zgui implementation |

---

## Notes

- zgui requires Zig 0.15.1+ (not compatible with Capy which needs 0.14.1)
- Vendor libraries already present: `vendor/zgui`, `vendor/zglfw`, `vendor/zopengl`
- OpenGL backend chosen for compatibility (works without GPU)
