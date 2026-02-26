# GearTracker-Zig Testing Plan

## Overview
This document outlines the testing plan for verifying the feature parity between GearTracker-Zig (Zig) and GearTracker (Python).

## Test Environment
- **Platform**: Linux
- **Build**: `zig build` in gearTracker-zig directory
- **Run**: `./zig-out/bin/gearTracker_zig`

---

## Phase 1: Firearms Tab

### CRUD Operations
- [ ] Add new firearm with all fields (Name, Caliber, Serial, Barrel, Trust, Status, Clean Interval, Oil Interval)
- [ ] Edit existing firearm
- [ ] Delete firearm
- [ ] Verify firearm appears in table

### Maintenance
- [ ] Click "Log Maintenance" button
- [ ] Verify Maintenance Type dropdown has all 13 types:
  - CLEANING, LUBRICATION, REPAIR, ZEROING, HUNTING, INSPECTION, FIRED_ROUNDS, OILING, RAIN_EXPOSURE, CORROSIVE_AMMO, LEAD_AMMO, OIL, OTHER
- [ ] Log maintenance with "FIRED_ROUNDS" - verify rounds added to firearm
- [ ] Log maintenance with "Reset rounds counter" checked - verify rounds reset to 0
- [ ] Click "View History" - verify maintenance log displays

### Transfer/Sell
- [ ] Select a firearm that is AVAILABLE (not checked out)
- [ ] Click "Transfer/Sell" button
- [ ] Fill in buyer details and save
- [ ] Verify firearm status changes to TRANSFERRED
- [ ] Try to transfer a CHECKED_OUT firearm - should be blocked

### Edge Cases
- [ ] Verify transfer is blocked for checked-out items
- [ ] Verify status dropdown includes TRANSFERRED option

---

## Phase 2: NFA Items Tab

### CRUD Operations
- [ ] Add new NFA item with all fields
- [ ] Verify NFA Type dropdown works (SUPPRESSOR, SBR, SBS, AOW, DD)
- [ ] Edit existing NFA item
- [ ] Delete NFA item

### Maintenance
- [ ] Click "Log Maintenance" for NFA item
- [ ] Verify maintenance logs work for NFA items
- [ ] Click "View History" for NFA item

---

## Phase 3: Attachments Tab

### CRUD Operations
- [ ] Add new attachment
- [ ] Verify "Mounted On" dropdown shows list of firearms
- [ ] Edit existing attachment
- [ ] Delete attachment

### Mount Functionality
- [ ] Select a firearm from dropdown when creating attachment
- [ ] Verify attachment shows mounted status

---

## Phase 4: Consumables Tab

### CRUD Operations
- [ ] Add new consumable
- [ ] Verify Category dropdown (AMMO, BATTERIES, HYGIENE, MEDICAL, CLEANING, OTHER)
- [ ] Verify Unit dropdown (rounds, count, oz, pairs, boxes)
- [ ] Edit existing consumable
- [ ] Delete consumable

### Stock Management
- [ ] Click "Add Stock" - verify quantity increases
- [ ] Click "Use Stock" - verify quantity decreases
- [ ] View stock transaction history

### Status Indicators
- [ ] Add consumable with quantity <= min_quantity
- [ ] Verify "LOW" status indicator appears in red

### History
- [ ] Click "View History" for consumable
- [ ] Verify ADD/USE transaction history displays

---

## Phase 5: Reloading Tab

### CRUD Operations
- [ ] Add new reload batch with all fields
- [ ] Edit existing reload batch
- [ ] Delete reload batch

### Test Results
- [ ] Select a reload batch
- [ ] Click "Log Results" button
- [ ] Fill in test results (Velocity, ES, SD, Group Size, etc.)
- [ ] Set status to APPROVED - verify status changes
- [ ] Set status to REJECTED - verify status changes

### Duplicate
- [ ] Click "Duplicate Batch" - verify copy is created with "(Copy)" suffix

---

## Phase 6: Loadouts Tab

### CRUD Operations
- [ ] Click "Create Loadout" - verify modal opens
- [ ] Add items to loadout using nested tabs (Firearms, Soft Gear, NFA Items, Consumables)
- [ ] Save loadout
- [ ] Verify loadout appears in table with item counts

### Edit/Duplicate
- [ ] Click "Edit Loadout" - verify modal populates with existing items
- [ ] Click "Duplicate Loadout" - verify copy is created

### Checkout
- [ ] Select loadout
- [ ] Click "Checkout Loadout"
- [ ] Enter borrower name and checkout
- [ ] Verify checkout is recorded

---

## Phase 7: Checkouts Tab

### Checkout Item (Individual)
- [ ] Click "Checkout Item" button
- [ ] Select item type (Firearm/Soft Gear/NFA Item)
- [ ] Enter borrower name
- [ ] Add notes
- [ ] Click Checkout
- [ ] Verify item status changes to CHECKED_OUT (for firearms/NFA)
- [ ] Verify checkout appears in table

### Return Item
- [ ] Select a checkout
- [ ] Click "Return Item"
- [ ] Enter rounds fired (if firearm)
- [ ] Click Return
- [ ] Verify item status changes back to AVAILABLE

---

## Phase 8: Borrowers Tab

### CRUD Operations
- [ ] Click "Add Borrower"
- [ ] Fill in Name, Phone, Email, Notes
- [ ] Save borrower
- [ ] Verify borrower appears in table

### Edit/Delete
- [ ] Select borrower and edit
- [ ] Delete borrower

---

## Phase 9: Transfers Tab

### Verification
- [ ] Navigate to Transfers tab
- [ ] Verify table shows: Firearm, Buyer, Date, Notes
- [ ] Verify transfers from Firearms tab appear here

---

## Phase 10: UI/UX

### Search
- [ ] Type in search box
- [ ] Verify table filters to show matching items
- [ ] Search works across name and other columns

### Status Indicators
- [ ] Low stock items show "LOW" status
- [ ] Delete buttons are red
- [ ] Checkout buttons are blue
- [ ] Disabled buttons are grayed out

### Form Hints
- [ ] Verify placeholder text helps users understand expected input

---

## General Testing

### Data Persistence
- [ ] Close and reopen application
- [ ] Verify all data persists in SQLite database

### Navigation
- [ ] Switch between all tabs
- [ ] Verify tab state is maintained

### Error Handling
- [ ] Try to save item with empty required fields
- [ ] Verify appropriate behavior

---

## Test Data

### Sample Firearm
- Name: "My Glock 19"
- Caliber: "9mm"
- Serial: "ABC123"
- Barrel: "4.0"
- Trust: "My Family Trust"
- Status: AVAILABLE

### Sample NFA Item
- Name: "SilencerCo Octane 45"
- Type: SUPPRESSOR
- Manufacturer: "SilencerCo"
- Serial: "NFA123"
- Tax Stamp: "123456789"

### Sample Consumable
- Name: "Federal 9mm 115gr FMJ"
- Category: AMMO
- Unit: rounds
- Quantity: 500
- Min Quantity: 100

### Sample Reload Batch
- Cartridge: ".308 Win"
- Bullet: "Hornady 150gr"
- Powder: "IMR 4895"
- Charge: 44.5

---

## Known Issues / Notes

_Record any issues discovered during testing here:_

- 
- 

---

*Last Updated: 2026-02-20*
