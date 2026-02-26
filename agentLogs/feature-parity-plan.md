# GearTracker-Zig Feature Parity Implementation Plan

## Executive Summary

This document details the implementation plan to achieve feature parity between the Python GearTracker application and the Zig rewrite. The Zig version uses zgui (Dear ImGui) with OpenGL backend and SQLite for data persistence.

---

## Current State Summary

| Layer | Status |
|-------|--------|
| **Models** | ✅ Complete (all 10 models) |
| **Database Schema** | ✅ Complete (all 14 tables) |
| **Repositories** | ✅ Complete (13 repositories, all CRUD) |
| **Services** | ✅ Complete (Checkout, Maintenance, Loadout) |
| **GUI** | ⚠️ Partial (only Firearms tab partially complete) |

### Existing Tabs in Zig (Partial)
- Firearms (CRUD + basic edit)
- Soft Gear (basic CRUD)
- NFA Items (basic display)
- Attachments (basic display)

### Missing Tabs in Zig
- Reloading
- Consumables
- Loadouts
- Checkouts
- Borrowers
- Transfers
- Import/Export

---

## Python Application Features (Reference)

The Python application has 11 tabs with the following features:

| Tab | Features |
|-----|----------|
| **Firearms** | Add, Edit, Delete, Log Maintenance, View History, Transfer/Sell, Maintenance alerts, Rounds tracking |
| **Attachments** | Add, Edit, Delete, Mount to firearm, Zero distance tracking |
| **Reloading** | Add/Edit/Delete batches, Duplicate, Log test results (velocity, ES, SD, group size), Status (WORKUP/APPROVED/REJECTED) |
| **Soft Gear** | Add, Edit, Delete, Log Maintenance, View History |
| **Consumables** | Add, Add Stock, Use Stock, Low stock alerts, History |
| **Loadouts** | Create/Edit/Duplicate, Add firearms/soft gear/NFA items/consumables, Checkout entire loadout |
| **Checkouts** | Checkout individual items or full loadouts, Return with rounds tracking, Auto-deduct consumables |
| **Borrowers** | Add, Delete (name, phone, email, notes) |
| **NFA Items** | Add, Edit, Delete, Log Maintenance, View History, Maintenance alerts, Tax stamp tracking |
| **Transfers** | View transfer history with buyer details |
| **Import/Export** | CSV export, CSV import, Template generation |

---

## Phase 1: Complete Firearms Tab (Priority: HIGH)

### Task 1.1: Expand Firearm Form
- [ ] Add Clean Interval field (spinbox, default 500)
- [ ] Add Oil Interval field (spinbox, default 90)
- [ ] Add Barrel Length field
- [ ] Add Trust Name field
- [ ] Add Purchase Date field
- **File**: `src/main.zig` - `saveItem()` function

### Task 1.2: Log Maintenance Dialog
- [ ] Create maintenance dialog modal
- [ ] Add Maintenance Type dropdown (Cleaning, Repair, Inspection, Oil, Fired Rounds, Rain Exposure, etc.)
- [ ] Add Rounds Fired input field
- [ ] Add Reset Rounds checkbox
- [ ] Add Details text field
- [ ] Link to MaintenanceLogRepository.create()
- **File**: `src/main.zig` - add `renderMaintenanceDialog()`

### Task 1.3: View History Dialog
- [ ] Create history view modal
- [ ] Query MaintenanceLogRepository for item
- [ ] Display table: Date, Type, Details, Rounds
- **File**: `src/main.zig` - add `renderHistoryDialog()`

### Task 1.4: Transfer/Sell Dialog
- [ ] Create transfer dialog modal
- [ ] Display firearm info (read-only)
- [ ] Add Buyer Name, Address, DL Number fields
- [ ] Add Optional: LTC Number, FFL Dealer, Sale Price
- [ ] On save: create Transfer record, update firearm status to TRANSFERRED
- **File**: `src/main.zig` - add `renderTransferDialog()`

---

## Phase 2: Complete NFA Items Tab (Priority: HIGH)

### Task 2.1: Implement Full NFA CRUD in UI
- [ ] Expand add form with all fields:
  - Name, NFA Type (dropdown), Manufacturer, Serial, Tax Stamp ID
  - Caliber/Bore, Form Type, Trust Name
  - Status dropdown, Notes
  - Clean Interval, Oil Interval
- [ ] Implement Edit functionality
- **File**: `src/main.zig` - NFA items section in `saveItem()`

### Task 2.2: NFA Maintenance & History
- [ ] Implement Log Maintenance (same pattern as firearms)
- [ ] Implement View History (same pattern as firearms)
- [ ] Handle rounds tracking for suppressors
- **File**: `src/main.zig`

---

## Phase 3: Complete Attachments Tab (Priority: HIGH)

### Task 3.1: Implement Full Attachment CRUD
- [ ] Expand add form with all fields:
  - Name, Category, Brand, Model, Serial
  - Mounted On (firearm dropdown), Mount Position
  - Zero Distance (yards), Zero Notes, Notes
- [ ] Implement Edit functionality
- **File**: `src/main.zig`

---

## Phase 4: Implement Consumables Tab (Priority: HIGH)

### Task 4.1: Create Consumables Table Display
- [ ] Add tab for Consumables
- [ ] Display table: Name, Category, Quantity + Unit, Min Qty, Status
- [ ] Highlight low stock items (red background)
- **File**: `src/main.zig`

### Task 4.2: Consumables CRUD
- [ ] Add dialog: Name, Category (dropdown), Unit, Quantity, Min Qty, Notes
- [ ] Implement Add, Edit, Delete
- **File**: `src/main.zig`

### Task 4.3: Add/Use Stock
- [ ] Add "Add Stock" button → dialog with quantity input
- [ ] Add "Use Stock" button → dialog with quantity input
- [ ] Update ConsumableRepository + ConsumableTransactionRepository
- **File**: `src/main.zig`

### Task 4.4: View History
- [ ] View transaction history for consumable
- **File**: `src/main.zig`

---

## Phase 5: Implement Reloading Tab (Priority: MEDIUM)

### Task 5.1: Reloading Table Display
- [ ] Add tab for Reloading
- [ ] Display table: Cartridge, Bullet, Powder, Created, Test Date, Status
- **File**: `src/main.zig`

### Task 5.2: Reload Batch CRUD
- [ ] Add dialog with fields:
  - Cartridge, Firearm (optional), Bullet Maker/Model/Weight
  - Powder Name/Charge/Lot, Primer Maker/Type
  - Case Brand, Times Fired, COAL, Crimp Style
  - Intended Use, Notes
- [ ] Implement Add, Edit, Delete, Duplicate
- **File**: `src/main.zig`

### Task 5.3: Log Test Results
- [ ] Add "Log Results" dialog:
  - Test Date, Avg Velocity, ES, SD
  - Group Size, Group Distance
  - Status (WORKUP/APPROVED/REJECTED)
- **File**: `src/main.zig`

---

## Phase 6: Implement Loadouts Tab (Priority: MEDIUM)

### Task 6.1: Loadouts Table Display
- [ ] Add tab for Loadouts
- [ ] Display table: Name, Description, Items, Consumables, Created
- **File**: `src/main.zig`

### Task 6.2: Create/Edit Loadout Dialog
- [ ] Create multi-tab dialog:
  - Tab 1: Name, Description, Notes
  - Tab 2: Select Firearms (checkboxes)
  - Tab 3: Select Soft Gear (checkboxes)
  - Tab 4: Select NFA Items (checkboxes)
  - Tab 5: Select Consumables (table with quantity spinboxes)
- [ ] Auto-include mounted attachments when firearm selected
- [ ] Implement Create, Edit, Duplicate
- **File**: `src/main.zig`

### Task 6.3: Checkout Loadout
- [ ] Select borrower from dropdown
- [ ] Set expected return date
- [ ] Checkout button: creates checkout records, updates item statuses
- **File**: `src/main.zig`

---

## Phase 7: Implement Checkouts Tab (Priority: MEDIUM)

### Task 7.1: Active Checkouts Display
- [ ] Add tab for Checkouts
- [ ] Display active checkouts: Item, Type, Borrower, Checkout Date, Notes
- **File**: `src/main.zig`

### Task 7.2: Checkout Individual Item
- [ ] Dialog: Select Item (available firearms/soft gear), Select Borrower, Return Date
- **File**: `src/main.zig`

### Task 7.3: Return Item Dialog
- [ ] Dialog with:
  - Item info, Borrower info, Checkout date
  - Rounds fired (if firearm)
  - Ammo type dropdown
  - Rain exposure checkbox
  - Notes field
- [ ] On return: update checkout, update rounds, create maintenance log
- **File**: `src/main.zig`

---

## Phase 8: Implement Borrowers Tab (Priority: MEDIUM)

### Task 8.1: Borrowers Table Display
- [ ] Add tab for Borrowers
- [ ] Display: Name, Phone, Email, Notes
- **File**: `src/main.zig`

### Task 8.2: Borrower CRUD
- [ ] Add dialog: Name, Phone, Email, Notes
- [ ] Implement Add, Delete
- **File**: `src/main.zig`

---

## Phase 9: Implement Transfers Tab (Priority: LOW)

### Task 9.1: Transfers Table Display
- [ ] Add tab for Transfers
- [ ] Display: Firearm, Buyer, Date, Price, Notes
- [ ] **File**: `src/main.zig`

### Task 9.2: View Transfer Details
- [ ] View buyer details, FFL info, etc.
- **File**: `src/main.zig`

---

## Phase 10: Implement Import/Export Tab (Priority: LOW)

### Task 10.1: Export to CSV
- [ ] Button to export all data to CSV
- [ ] Or export by entity type
- **File**: `src/main.zig`

### Task 10.2: Import from CSV
- [ ] Preview button (dry run)
- [ ] Import button with validation
- **File**: `src/main.zig`

### Task 10.3: Template Generation
- [ ] Generate blank templates for each entity type
- **File**: `src/main.zig`

---

## Phase 11: UI Polish (Priority: MEDIUM)

### Task 11.1: Tooltips
- [ ] Add tooltip for truncated Notes column in all tables

### Task 11.2: Status Indicators
- [ ] Highlight CHECKED_OUT items (red background)
- [ ] Highlight items needing maintenance (red background)
- [ ] Highlight low-stock consumables (yellow background)

### Task 11.3: Search/Filter
- [ ] Ensure search works across all tabs

### Task 11.4: Keyboard Shortcuts
- [ ] Add common shortcuts (Ctrl+N for new, etc.)

---

## Implementation Files

| File | Changes Needed |
|------|---------------|
| `src/main.zig` | Major rewrite - add all 11 tabs, dialogs |
| `src/repository/database.zig` | ✅ Already complete |
| `src/models/*.zig` | ✅ Already complete |
| `src/services/*.zig` | ✅ Already complete |

---

## Estimated Complexity

| Phase | Tasks | Complexity |
|-------|-------|------------|
| Phase 1-3 | 10 tasks | HIGH |
| Phase 4 | 4 tasks | MEDIUM |
| Phase 5 | 3 tasks | MEDIUM |
| Phase 6 | 3 tasks | HIGH |
| Phase 7 | 3 tasks | MEDIUM |
| Phase 8 | 2 tasks | LOW |
| Phase 9 | 2 tasks | LOW |
| Phase 10 | 3 tasks | LOW |
| Phase 11 | 4 tasks | LOW |

---

## Technology Stack

- **Language**: Zig 0.15.x
- **GUI Framework**: zgui (Dear ImGui) with OpenGL backend
- **Windowing**: zglfw (GLFW bindings)
- **Database**: SQLite3 (via C FFI)
- **Build System**: Zig build system

### System Dependencies
- OpenGL headers: `/usr/include/GL/`
- GLFW headers: `/usr/include/GLFW/`
- GLFW library: `/usr/lib/libglfw.so`
- OpenGL library: `/usr/lib/libGL.so`

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

## Database Schema

The SQLite database uses the following tables:

1. `firearms` - Firearm inventory
2. `soft_gear` - Soft gear inventory
3. `consumables` - Ammo, batteries, etc.
4. `consumable_transactions` - Stock transactions
5. `maintenance_logs` - Maintenance history
6. `borrowers` - People who can borrow gear
7. `checkouts` - Active/outstanding checkouts
8. `nfa_items` - NFA-regulated items
9. `transfers` - Transfer/sale history
10. `attachments` - Scopes, lights, etc.
11. `reload_batches` - Reloading data
12. `loadouts` - Pre-configured loadouts
13. `loadout_items` - Items in loadouts
14. `loadout_consumables` - Consumables in loadouts

---

## Repository Pattern

All data access follows the repository pattern with these repositories:

- `FirearmRepository` - CRUD for firearms
- `SoftGearRepository` - CRUD for soft gear
- `ConsumableRepository` - CRUD for consumables
- `ConsumableTransactionRepository` - Stock transactions
- `BorrowerRepository` - CRUD for borrowers
- `CheckoutRepository` - CRUD for checkouts
- `MaintenanceLogRepository` - CRUD for maintenance logs
- `NFAItemRepository` - CRUD for NFA items
- `AttachmentRepository` - CRUD for attachments
- `TransferRepository` - CRUD for transfers
- `ReloadBatchRepository` - CRUD for reload batches
- `LoadoutRepository` - CRUD for loadouts
- `LoadoutItemRepository` - Items in loadouts
- `LoadoutConsumableRepository` - Consumables in loadouts

---

## Services Layer

Business logic is encapsulated in services:

- `CheckoutService` - Checkout/return operations
- `MaintenanceService` - Maintenance tracking
- `LoadoutService` - Loadout management

---

## Notes

- All string fields in models use `[]const u8` for Zig compatibility
- Timestamps are stored as Unix epoch integers (i64)
- The application uses a General Purpose Allocator (GPA) for memory management
- Database path: `~/.gear_tracker/tracker.db`
