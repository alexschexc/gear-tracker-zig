# GearTracker-Zig Session Log

**Date:** 2026-02-17
**Session:** SQLite Fix & CRUD Implementation

## Summary

Fixed the persistent SQLite segfault issue and implemented initial Firearm CRUD operations.

## Problem: SQLite Segfault

### Initial Symptom
- Application crashed with segfault at `sqlite3_open` even though:
  - C test program worked fine
  - SQLite was properly linked
  - Correct path was provided

### Root Cause
Zig's `@cImport` was generating incorrect function signatures for `sqlite3_open`, causing the function pointer to be null (address 0x0).

### Solution
Used explicit type casting with `@as()` to properly handle C pointer types:

```zig
const open_result = c.sqlite3_open(
    @as([*c]const u8, @ptrCast(path_buf.ptr)), 
    @as([*c]?*c.sqlite3, @ptrCast(&db_ref))
);
```

This forced Zig to correctly interpret the pointer types when calling the C function.

## Additional Fixes

1. **Zig 0.15 compatibility**: Changed `std.os.getenv` to `std.posix.getenv`
2. **Error handling**: Used stack buffer instead of error-returning allocation in `main()`

## CRUD Implementation

### Database Helper Functions
Added to `src/repository/database.zig`:
- `prepare(sql)` - prepare SQL statements
- `step(stmt)` - iterate through results  
- `columnText(stmt, col)` - get text value
- `columnInt(stmt, col)` - get int value
- `columnInt64(stmt, col)` - get int64 value
- `finalize(stmt)` - clean up statement
- `exec(sql)` - execute SQL directly

### FirearmRepository
Added `src/repository/database.zig`:
- `create(fw)` - insert new firearm (19 columns → 23 columns fixed)
- `getAll()` - get all owned firearms
- `getById(id)` - get firearm by ID
- `updateStatus(id, status)` - update checkout status
- `delete(id)` - delete firearm and related records

### Model Updates
- Changed `Firearm` struct fields from `[]u8` to `[]const u8` for compatibility

## Test Results

```
Found 3 firearms
  - Pistol (Glock 19)
  - Rifle (AR-15)
  - Shotgun (Benelli M2)
```

Successfully reading from existing database at `~/.gear_tracker/tracker.db`.

## Remaining Work

1. Add memory cleanup for getAll results (leaks detected)
2. Add CRUD for other tables:
   - SoftGear
   - Consumable  
   - Checkout
   - Borrower
   - Loadout
   - MaintenanceLog
   - etc.
3. Implement services layer
4. Add Dear ImGui GUI

## Files Modified

- `src/repository/database.zig` - Added helpers + FirearmRepository
- `src/models/firearm.zig` - Changed field types to `[]const u8`
- `src/root.zig` - Export FirearmRepository
- `src/main.zig` - Test CRUD operations
- `build.zig` - Added libc linking
