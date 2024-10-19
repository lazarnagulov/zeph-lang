const std = @import("std");

const o = @import("object.zig");

const Object = o.Object;

pub const Environment = struct {
    allocator: std.mem.Allocator,
    store: std.StringHashMap(Object),
    outer: ?*Environment,

    const Self = @This();

    pub fn initEnclose(allocator: std.mem.Allocator, outer: *Environment) Environment {
        var env = init(allocator);
        env.outer = outer;
        return env;
    }

    pub fn init(allocator: std.mem.Allocator) Environment {
        return .{
            .allocator = allocator,
            .store = std.StringHashMap(Object).init(allocator),
            .outer = null,
        };
    }

    pub fn get(self: *Self, name: []const u8) ?Object {
        const value = self.store.get(name);
        if (value) |val| {
            return val;
        }
        if (self.outer) |env| {
            return env.get(name);
        }
        return null;
    }

    pub fn set(self: *Self, name: []const u8, value: *Object) !Object {
        try self.store.put(try self.allocator.dupe(u8, name), value.*);
        return value.*;
    }
};
