const std = @import("std");

const o = @import("object.zig");

const Object = o.Object;

pub const Environment = struct {
    allocator: std.mem.Allocator,
    store: std.StringHashMap(Object),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Environment {
        return .{
            .allocator = allocator,
            .store = std.StringHashMap(Object).init(allocator),
        };
    }

    pub fn get(self: *Self, name: []const u8) ?*Object {
        return self.store.getPtr(name);
    }

    pub fn set(self: *Self, name: []const u8, value: *const Object) !Object {
        try self.store.put(try self.allocator.dupe(u8, name), value.*);
        return value.*;
    }
};
