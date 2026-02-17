const std = @import("std");

pub const CheckoutStatus = enum(u8) {
    available = 0,
    checked_out = 1,
    lost = 2,
    retired = 3,

    pub fn fromString(s: []const u8) CheckoutStatus {
        if (std.mem.eql(u8, s, "CHECKED_OUT")) return .checked_out;
        if (std.mem.eql(u8, s, "LOST")) return .lost;
        if (std.mem.eql(u8, s, "RETIRED")) return .retired;
        return .available;
    }

    pub fn toString(self: CheckoutStatus) []const u8 {
        return switch (self) {
            .available => "AVAILABLE",
            .checked_out => "CHECKED_OUT",
            .lost => "LOST",
            .retired => "RETIRED",
        };
    }
};

pub const MaintenanceType = enum(u8) {
    cleaning = 0,
    repair = 1,
    inspection = 2,
    oil = 3,
    other = 4,

    pub fn fromString(s: []const u8) MaintenanceType {
        if (std.mem.eql(u8, s, "REPAIR")) return .repair;
        if (std.mem.eql(u8, s, "INSPECTION")) return .inspection;
        if (std.mem.eql(u8, s, "OIL")) return .oil;
        if (std.mem.eql(u8, s, "OTHER")) return .other;
        return .cleaning;
    }

    pub fn toString(self: MaintenanceType) []const u8 {
        return switch (self) {
            .cleaning => "CLEANING",
            .repair => "REPAIR",
            .inspection => "INSPECTION",
            .oil => "OIL",
            .other => "OTHER",
        };
    }
};

pub const GearCategory = enum(u8) {
    firearm = 0,
    soft_gear = 1,
    consumable = 2,
    nfa_item = 3,
    attachment = 4,

    pub fn fromString(s: []const u8) GearCategory {
        if (std.mem.eql(u8, s, "SOFT_GEAR")) return .soft_gear;
        if (std.mem.eql(u8, s, "CONSUMABLE")) return .consumable;
        if (std.mem.eql(u8, s, "NFA_ITEM")) return .nfa_item;
        if (std.mem.eql(u8, s, "ATTACHMENT")) return .attachment;
        return .firearm;
    }

    pub fn toString(self: GearCategory) []const u8 {
        return switch (self) {
            .firearm => "FIREARM",
            .soft_gear => "SOFT_GEAR",
            .consumable => "CONSUMABLE",
            .nfa_item => "NFA_ITEM",
            .attachment => "ATTACHMENT",
        };
    }
};

pub const NFAItemType = enum(u8) {
    suppressor = 0,
    sbr = 1,
    sbs = 2,
    aow = 3,
    dd = 4,

    pub fn fromString(s: []const u8) NFAItemType {
        if (std.mem.eql(u8, s, "SBR")) return .sbr;
        if (std.mem.eql(u8, s, "SBS")) return .sbs;
        if (std.mem.eql(u8, s, "AOW")) return .aow;
        if (std.mem.eql(u8, s, "DD")) return .dd;
        return .suppressor;
    }

    pub fn toString(self: NFAItemType) []const u8 {
        return switch (self) {
            .suppressor => "SUPPRESSOR",
            .sbr => "SBR",
            .sbs => "SBS",
            .aow => "AOW",
            .dd => "DD",
        };
    }
};

pub const NFAFirearmType = enum(u8) {
    sbr = 0,
    sbs = 1,

    pub fn fromString(s: []const u8) NFAFirearmType {
        if (std.mem.eql(u8, s, "SBS")) return .sbs;
        return .sbr;
    }

    pub fn toString(self: NFAFirearmType) []const u8 {
        return switch (self) {
            .sbr => "SBR",
            .sbs => "SBS",
        };
    }
};

pub const TransferStatus = enum(u8) {
    owned = 0,
    transferred = 1,

    pub fn fromString(s: []const u8) TransferStatus {
        if (std.mem.eql(u8, s, "TRANSFERRED")) return .transferred;
        return .owned;
    }

    pub fn toString(self: TransferStatus) []const u8 {
        return switch (self) {
            .owned => "OWNED",
            .transferred => "TRANSFERRED",
        };
    }
};

pub const ReloadStatus = enum(u8) {
    workup = 0,
    approved = 1,
    rejected = 2,

    pub fn fromString(s: []const u8) ReloadStatus {
        if (std.mem.eql(u8, s, "APPROVED")) return .approved;
        if (std.mem.eql(u8, s, "REJECTED")) return .rejected;
        return .workup;
    }

    pub fn toString(self: ReloadStatus) []const u8 {
        return switch (self) {
            .workup => "WORKUP",
            .approved => "APPROVED",
            .rejected => "REJECTED",
        };
    }
};

pub const ConsumableCategory = enum(u8) {
    ammo = 0,
    batteries = 1,
    hygiene = 2,
    medical = 3,
    cleaning = 4,
    other = 5,

    pub fn fromString(s: []const u8) ConsumableCategory {
        if (std.mem.eql(u8, s, "BATTERIES")) return .batteries;
        if (std.mem.eql(u8, s, "HYGIENE")) return .hygiene;
        if (std.mem.eql(u8, s, "MEDICAL")) return .medical;
        if (std.mem.eql(u8, s, "CLEANING")) return .cleaning;
        if (std.mem.eql(u8, s, "OTHER")) return .other;
        return .ammo;
    }

    pub fn toString(self: ConsumableCategory) []const u8 {
        return switch (self) {
            .ammo => "AMMO",
            .batteries => "BATTERIES",
            .hygiene => "HYGIENE",
            .medical => "MEDICAL",
            .cleaning => "CLEANING",
            .other => "OTHER",
        };
    }
};

pub const TransactionType = enum(u8) {
    add = 0,
    use = 1,

    pub fn fromString(s: []const u8) TransactionType {
        if (std.mem.eql(u8, s, "USE")) return .use;
        return .add;
    }

    pub fn toString(self: TransactionType) []const u8 {
        return switch (self) {
            .add => "ADD",
            .use => "USE",
        };
    }
};
