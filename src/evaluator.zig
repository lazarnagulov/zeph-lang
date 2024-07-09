const std = @import("std");
const ast = @import("ast.zig");
const o = @import("object.zig");

const Node = ast.Node;
const Program = ast.Program;
const Expression = ast.Expression;
const Statement = ast.Statement;

const Object = o.Object;
const Integer = o.Integer;
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

    pub fn evalNode(self: *Self, node: Node) !*Object {
        return switch (node) {
            // .program => |program| return try self.evalProgram(program),
            .statement => |statement| try self.evalStatement(statement),
            .expression => |expression| try self.evalExpression(expression),
        };
    }

    pub fn evalProgram(self: *Self, program: *Program) !*Object {
        var result: *Object = &Object{ .null = Null{} };
        for (program.statemets.items) |statement| {
            const evaluated = try self.evalStatement(&statement);
            switch (evaluated.*) {
                .keyword_return => |ret| return ret.value,
                else => result = evaluated,
            }
        }
        return result;
    }

    pub fn evalStatement(self: *Self, statement: *Statement) *Object {
        return switch (statement.*) {
            .expression_statement => |expression_statement| self.evalExpression(expression_statement.expression),
            else => EvaluationError.InvalidStatement,
        };
    }

    pub fn evalExpression(self: *Self, expression: *Expression) *Object {
        return switch (expression.*) {
            .int_literal => |integer| try Integer.init(&self.allocator, integer.value),
            else => EvaluationError.InvalidExpression,
        };
    }
};
