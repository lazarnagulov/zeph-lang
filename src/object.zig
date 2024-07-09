const std = @import("std");

const EvaluationError = @import("evaluator_error.zig").EvaluationError;

pub const Object = union(enum) {
    integer: Integer,
    boolean: Boolean,
    null_val: Null,
};

pub const Integer = struct {
    value: i64,

    pub fn init(allocator: *std.mem.Allocator, value: i64) !*Object {
        const integer = allocator.create(Object) catch return EvaluationError.OutOfMemory;
        integer.* = Object{ .integer = Integer{ .value = value } };
        return integer;
    }
};
pub const Boolean = struct {
    value: bool,

    pub fn init(allocator: *std.mem.Allocator, value: bool) !*Object {
        const boolean = allocator.create(Object) catch return EvaluationError.OutOfMemory;
        boolean.* = Object{ .boolean = Boolean{ .value = value } };
        return boolean;
    }
};
pub const Null = struct {};
