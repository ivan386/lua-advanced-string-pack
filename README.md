# lua-advanced-string-pack
upgrade for standard lua string.pack


## Examples:

```lua
> require "advanced-string-pack"
```
Import "advanced string pack"

```lua
> string.format("%q", string.pack("[B]{B}", 4, 1, 2, 3, 4))
"\4\1\2\3\4"

> string.unpack("[B]{B}", "\4\1\2\3\4")
4       1       2       3       4       6
```
Use first value in squere brackets as count and repeat format in figure brackets

```lua
> string.format("%q", string.pack("(B){B, H, L}", 3, 1))
"\3\1\0\0\0"

> string.unpack("(B){B, H, L}", "\3\1\0\0\0")
3       1       6
```
Use first value as key and found format in figure brackets by that key. Indexes start from 1.


```lua
> string.format("%q", string.pack("(BB){B, H, L}", 3, 2, 1))
"\3\2\1\0"

> string.unpack("(BB){B, H, L}", "\3\2\1\0")
3       2       1       5

```
If brackets have more then one value in there then used last.


```lua
> string.format("%q", string.pack("(*BB){B, H, L}", 3, 2, 1))
"\3\2\1\0\0\0"

> string.unpack("(*BB){B, H, L}", "\3\2\1\0\0\0")
3       2       1       7
```
Star can change that rule. It mean return next value.

```lua
> string.format("%q", string.pack("(B){0:B, H, L, s1}", 3, "test"))
"\3\4test"

> string.unpack("(B){0:B, H, L, s1}", "\3\4test")
3       test    7
```
Now indexes start from zero.

```lua
> string.format("%q", string.pack("(s1){test: s1}", "test", "done"))
"\4test\4done"

> string.unpack("(s1){test: s1}", "\4test\4done")
test    done    11
```
Index can be a string. It start from bracket or comma and continues to colon. It must not contain any brackets.


```lua
> string.format("%q", string.pack("(s1){*: s1}", "test", "done"))
"\4test\4done"

> string.unpack("(s1){*: s1}", "\4test\4done")
test    done    11
```
Index can be a star. In mean that in key can be any value.

```lua
> require "serialize" -- https://github.com/ivan386/lua-serialize
true
> serialize( string.unpack("(s1){test: s1}", "\4test\4done", 1, true) , nil)
({
        "test",
        {
                "done"
        }})

> serialize( string.unpack("[B]{B}", "\4\1\2\3\4", 1, true) , nil)
({
        4,
        {
                {
                        1
                },
                {
                        2
                },
                {
                        3
                },
                {
                        4
                }
        }})
```
In "advanced string pack" string.unpack have tree mode. In this mode results return in tables. Every fugure bracket make new table for results.

```
> string.format("%q", string.pack("(s1){test: s1}", {"test",{"done"}}))
"\4test\4done"
```
In arguments for string.pack can be tables. string.pack ingnores tables structure. Counts only order of arguments in tables.
