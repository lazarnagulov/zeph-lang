# **Zeph**

***Zeph*** is an interpreted programming language inspired by [Monkey Language](https://interpreterbook.com/) written primarily for learning the Zig programming language.

### IF expression
- Must end with keyword **end**, can have **else**:
```
let result = if (a < b):
    return false;
else
    if (b == a):
        return false;
    else
        return true;
    end;
end;
```

### Functions
```
let my_function = fn(a,b,c):
    return a + b + c;
end;
```


