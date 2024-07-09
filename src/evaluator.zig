const std = @import("std");
const ast = @import("ast.zig");
const o = @import("object.zig");

const Node = ast.Node;
const Program = ast.Program;
const Expression = ast.Expression;
const Statement = ast.Statement;

const Object = o.Object;
const Integer = o.Integer;
const Boolean = o.Boolean;
const Null = o.Null;

const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;

const EvaluationError = @import("evaluator_error.zig").EvaluationError;

pub const Evaluator = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Evaluator {
        return Evaluator{ .allocator = allocator };
    }

    pub fn evalProgram(self: *Self, program: *Program) !*const Object {
        var result: *const Object = &Object{ .null_val = Null{} };
        for (program.statemets.items) |statement| {
            const evaluated = try self.evalStatement(&statement);
            result = evaluated;
        }
        return result;
    }

    fn evalNode(self: *Self, node: Node) !*const Object {
        return switch (node) {
            .program => |program| return try self.evalProgram(program),
            .statement => |statement| try self.evalStatement(statement),
            .expression => |expression| try self.evalExpression(expression),
        };
    }

    fn evalStatement(self: *Self, statement: *const Statement) !*const Object {
        return switch (statement.*) {
            .expression_statement => |expression_statement| self.evalExpression(expression_statement.expression),
            else => EvaluationError.InvalidStatement,
        };
    }

    fn evalExpression(self: *Self, expression: *const Expression) !*const Object {
        return switch (expression.*) {
            .int_literal => |integer| try Integer.init(&self.allocator, integer.value),
            .boolean => |boolean| try Boolean.init(&self.allocator, boolean.value),
            .prefix_expression => |prefix_expression| blk: {
                const right = try self.evalExpression(prefix_expression.right);
                break :blk self.evalPrefixExpression(prefix_expression.operator, right);
            },
            .infix_expression => |infix_expression| blk: {
                const left = try self.evalExpression(infix_expression.left);
                const right = try self.evalExpression(infix_expression.right);
                break :blk self.evalInfixExpression(infix_expression.operator, left, right);
            },
            else => EvaluationError.InvalidExpression,
        };
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
