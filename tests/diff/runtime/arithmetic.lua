-- expect: pass
-- stage: runtime
-- feature: arithmetic
-- normalize: none

print(1 + 2)
print(9 // 4)
print(7 % 4)
print(2 ^ 8)
print(5 / 2)
print(1.5 + 2.25)
print(6 - 4)
print(3 * 4)
print(-5)
local string_mt = getmetatable("")
string_mt.__bor = function(x, y) return math.tointeger(tonumber(x)) | math.tointeger(tonumber(y)) end
string_mt.__band = function(x, y) return math.tointeger(tonumber(x)) & math.tointeger(tonumber(y)) end
print(0xF0.0 | "0x0F.0")
print(" \t-0xfffffffffffffffe\n\t" & "-1")
print(1 >> math.mininteger, -1 << math.mininteger)
