const std = @import("std");
const ast = @import("ast.zig");
const o = @import("object.zig");

const Node = ast.Node;
const Program = ast.Program;
const Expression = ast.Expression;
const Statement = ast.Statement;
const IfExpression = ast.IfExpression;
const BlockStatement = ast.BlockStatement;
const Return = ast.Return;
const Identifier = ast.Identifier;

const Environment = @import("environment.zig").Environment;

const Object = o.Object;
const Integer = o.Integer;
const Boolean = o.Boolean;
const Null = o.Null;

const EvaluationError = @import("evaluator_error.zig").EvaluationError;

pub const Evaluator = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Evaluator {
        return Evaluator{ .allocator = allocator };
    }

    pub fn evalProgram(self: *Self, program: *Program, environment: *Environment) !*const Object {
        var result: Object = Object{ .null_val = Null{} };
        for (program.statemets.items) |statement| {
            const evaluated = try self.evalStatement(&statement, environment);
            switch (evaluated.*) {
                .ret => |ret| return ret.value,
                else => |eval| result = eval,
            }
        }
        return &result;
    }

    fn evalNode(self: *Self, node: Node, environment: *Environment) !*const Object {
        return switch (node) {
            .program => |program| return try self.evalProgram(program, environment),
            .statement => |statement| try self.evalStatement(statement, environment),
            .expression => |expression| try self.evalExpression(expression, environment),
        };
    }

    fn evalStatement(self: *Self, statement: *const Statement, environment: *Environment) !*const Object {
        return switch (statement.*) {
            .block_statement => |block_statement| try self.evalBlockStatement(block_statement, environment),
            .expression_statement => |expression_statement| try self.evalExpression(expression_statement.expression, environment),
            .ret => |ret| blk: {
                const value = try self.evalExpression(ret.return_value, environment);
                const object = self.allocator.create(Object) catch return EvaluationError.OutOfMemory;

                object.* = .{ .ret = o.ReturnValue{ .value = value } };

                break :blk object;
            },
            .let => |let| blk: {
                const value = try self.evalExpression(let.value, environment);
                break :blk &try environment.set(let.name.value, value);
            },
        };
    }

    fn evalExpression(self: *Self, expression: *const Expression, environment: *Environment) !*const Object {
        return switch (expression.*) {
            .int_literal => |integer| try Integer.init(&self.allocator, integer.value),
            .boolean => |boolean| try Boolean.init(&self.allocator, boolean.value),
            .prefix_expression => |prefix_expression| blk: {
                const right = try self.evalExpression(prefix_expression.right, environment);
                break :blk self.evalPrefixExpression(prefix_expression.operator, right);
            },
            .identifier => |identifier| blk: {
                if (environment.get(identifier.value)) |obj| {
                    break :blk obj;
                }
                break :blk EvaluationError.InvalidIdentifier;
            },
            .infix_expression => |infix_expression| blk: {
                const left = try self.evalExpression(infix_expression.left, environment);
                const right = try self.evalExpression(infix_expression.right, environment);
                break :blk self.evalInfixExpression(infix_expression.operator, left, right);
            },
            .if_expression => |if_expression| try self.evalIfExpression(if_expression, environment),
            else => EvaluationError.InvalidExpression,
        };
    }

    fn evalIfExpression(self: *Self, if_expression: *IfExpression, environment: *Environment) EvaluationError!*const Object {
        const consequnce = if_expression.consequence;
        var alternative: ?BlockStatement = null;
        if (if_expression.alternative) |alt| {
            alternative = alt;
        }
        const condition = try self.evalExpression(if_expression.condition, environment);

        if (try isThruty(condition)) {
            return try self.evalBlockStatement(consequnce, environment);
        } else if (alternative) |alt| {
            return try self.evalBlockStatement(alt, environment);
        }

        return &Object{ .null_val = Null{} };
    }

    fn isThruty(obj: *const Object) !bool {
        return switch (obj.*) {
            .boolean => |boolean| boolean.value,
            .null_val => false,
            else => EvaluationError.InvalidExpression,
        };
    }

    fn evalBlockStatement(self: *Self, block: BlockStatement, environment: *Environment) EvaluationError!*const Object {
        var result = Object{ .null_val = Null{} };
        for (block.statements.items) |statement| {
            const evaluated = try self.evalStatement(&statement, environment);
            switch (evaluated.*) {
                .ret => |ret| return ret.value,
                else => result = evaluated.*,
            }
        }
        return &result;
    }

    fn evalInfixExpression(self: *Self, operator: []const u8, left: *const Object, right: *const Object) !*const Object {
        return switch (left.*) {
            .integer => |left_integer| blk: {
                switch (right.*) {
                    .integer => |right_integer| break :blk self.evalIntegerInfixExpression(operator, &left_integer, &right_integer),
                    else => break :blk EvaluationError.InvalidOperator,
                }
            },
            .boolean => |left_boolean| blk: {
                switch (right.*) {
                    .boolean => |right_boolean| break :blk self.evalBooleanInfixExpression(operator, &left_boolean, &right_boolean),
                    else => break :blk EvaluationError.InvalidOperator,
                }
            },
            else => EvaluationError.InvalidOperator,
        };
    }

    fn evalBooleanInfixExpression(self: *Self, operator: []const u8, left: *const Boolean, right: *const Boolean) EvaluationError!*Object {
        return try switch (operator[0]) {
            '=' => blk: {
                if (operator.len == 2 and operator[1] == '=') {
                    break :blk Boolean.init(&self.allocator, left.*.value == right.*.value);
                }
                break :blk EvaluationError.InvalidOperator;
            },
            '!' => blk: {
                if (operator.len == 2 and operator[1] == '=') {
                    break :blk Boolean.init(&self.allocator, left.*.value != right.*.value);
                }
                break :blk EvaluationError.InvalidOperator;
            },
            else => EvaluationError.InvalidOperator,
        };
    }

    fn evalIntegerInfixExpression(self: *Self, operator: []const u8, left: *const Integer, right: *const Integer) EvaluationError!*Object {
        return try switch (operator[0]) {
            '+' => Integer.init(&self.allocator, left.*.value + right.*.value),
            '-' => Integer.init(&self.allocator, left.*.value - right.*.value),
            '*' => Integer.init(&self.allocator, left.*.value * right.*.value),
            '/' => Integer.init(&self.allocator, @divFloor(left.*.value, right.*.value)),
            '<' => Boolean.init(&self.allocator, left.*.value < right.*.value),
            '>' => blk: {
                if (operator.len == 2 and operator[1] == '=') {
                    break :blk Boolean.init(&self.allocator, left.*.value >= right.*.value);
                }
                break :blk Boolean.init(&self.allocator, left.*.value > right.*.value);
            },
            '=' => blk: {
                if (operator.len == 2 and operator[1] == '=') {
                    break :blk Boolean.init(&self.allocator, left.*.value == right.*.value);
                }
                break :blk EvaluationError.InvalidOperator;
            },
            '!' => blk: {
                if (operator.len == 2 and operator[1] == '=') {
                    break :blk Boolean.init(&self.allocator, left.*.value != right.*.value);
                }
                break :blk EvaluationError.InvalidOperator;
            },
            else => EvaluationError.InvalidOperator,
        };
    }

    fn evalPrefixExpression(self: *Self, operator: []const u8, right: *const Object) !*const Object {
        return switch (operator[0]) {
            '!' => self.evalBangOperatorExpression(right),
            '-' => self.evalMinusOperatorExpression(right),
            else => EvaluationError.InvalidOperator,
        };
    }

    fn evalBangOperatorExpression(self: *Self, right: *const Object) !*const Object {
        return switch (right.*) {
            .boolean => |boolean| blk: {
                if (boolean.value) {
                    break :blk try Boolean.init(&self.allocator, false);
                }
                break :blk try Boolean.init(&self.allocator, true);
            },
            .null_val => try Boolean.init(&self.allocator, true),
            else => try Boolean.init(&self.allocator, false),
        };
    }

    fn evalMinusOperatorExpression(self: *Self, right: *const Object) !*const Object {
        return switch (right.*) {
            .integer => |integer| Integer.init(&self.allocator, -integer.value),
            else => EvaluationError.InvalidOperator,
        };
    }
};

test "Test" {}
