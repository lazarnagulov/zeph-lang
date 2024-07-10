pub const EvaluationError = error{
    OutOfMemory,
    InvalidOperator,
    InvalidIdentifier,
    InvalidExpression,
    InvalidStatement,
};
