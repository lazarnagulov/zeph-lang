const std = @import("std");
const ast = @import("ast.zig");

const EvaluationError = @import("errors/evaluator_error.zig").EvaluationError;
const Environment = @import("environment.zig").Environment;

pub const Object = union(enum) {
    integer: Integer,
    boolean: Boolean,
    null_val: Null,
    function: Function,
    ret: ReturnValue,
};

pub const Integer = struct {
    value: i64,

    pub fn init(allocator: *std.mem.Allocator, value: i64) !Object {
        const integer = allocator.create(Object) catch return EvaluationError.OutOfMemory;
        integer.* = Object{ .integer = Integer{ .value = value } };
        return integer.*;
    }
};
pub const Boolean = struct {
    value: bool,

    pub fn init(allocator: *std.mem.Allocator, value: bool) !Object {
        const boolean = allocator.create(Object) catch return EvaluationError.OutOfMemory;
        boolean.* = Object{ .boolean = Boolean{ .value = value } };
        return boolean.*;
    }
};

pub const ReturnValue = struct {
    value: *Object,
};

pub const Function = struct {
    paramaters: std.ArrayList(ast.Identifier),
    body: ast.BlockStatement,
    environment: *Environment,

    pub fn init(allocator: *std.mem.Allocator, parameters: *const std.ArrayList(ast.Identifier), body: ast.BlockStatement, environment: *Environment) !Object {
        const function = allocator.create(Object) catch return EvaluationError.OutOfMemory;
        function.* = .{ .function = .{
            .paramaters = parameters.*,
            .body = body,
            .environment = environment,
        } };
        return function.*;
    }
};

pub const Null = struct {};
