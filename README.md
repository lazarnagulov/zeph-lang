# **Zeph**

***Zeph*** is an interpreted programming language inspired by [Monkey Language](https://interpreterbook.com/) written primarily for learning the Zig programming language.

## Syntax

## Variables

- Create variable with  `let variable_name = value;`
```
let number = 10;
let boolean = true;
```
### IF expression
- Must end with keyword **end**, can have **else**:
```
let a = 10; 
let b = 20;
let result = if (a < b):
    false;
else
    if (b == a):
        false;
    else
        true;
    end;
end;
```

### Function expression
- You can make function with `let function_name = fn(arguments...): end;`
- Return value is the last expression in function:
```
let square = fn(a):
    a * a;
end;
```
- You can also explicitly return value:
```
let explicit_return = fn(a, b):
    if(a + b >= 100):
        return 100;
    else
        return a + b;
    end;
end;
```
- Example of currying:
```
let outer = fn(a):
    let inner = fn(b):
        a + b;
    end;
    inner;
end;
```
- Call function with:
```
square(5);
explicit_return(60, 50);
outer(10)(5);
```


