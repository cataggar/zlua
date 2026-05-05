-- expect: pass
-- stage: stdlib
-- feature: stdlib-math-utf8
-- normalize: none

print(math.abs(-3), math.ceil(1.2), math.floor(1.8), math.fmod(7, 3))
print(math.max(1, 5, 3), math.min(1, 5, 3), math.modf(2.75))
print(math.type(1), math.type(1.5), math.tointeger(2.0), math.tointeger(2.5) == nil)
print(math.ult(-1, 1), math.ult(1, -1))
print(math.sqrt(9), math.sin(0), math.cos(0), math.tan(0))
print(math.acos(1), math.asin(0), math.atan(0), math.exp(0), math.huge > 1e300)
print(math.rad(180) > 3.14, math.deg(math.pi), math.log(8, 2))
math.randomseed(7)
local r = math.random(1, 3)
print(r >= 1 and r <= 3)

local s = utf8.char(65, 0x20ac)
print(s, utf8.len(s), utf8.codepoint(s, 1, -1))
print(utf8.offset(s, 2), utf8.offset(s, 0, 2))
local codes = {}
for pos, code in utf8.codes(s) do
  table.insert(codes, pos .. ":" .. code)
end
print(table.concat(codes, ","))
