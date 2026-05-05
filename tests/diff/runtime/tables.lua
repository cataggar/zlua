-- expect: pass
-- stage: runtime
-- feature: table
-- normalize: none

local a = {10, 20, 30}
print(#a, a[1], a[2], a[3], a[4])
a[2] = nil
print(a[2] == nil)
a[2] = 25
a[3] = nil
print(#a, a[1], a[2], a[3])

local h = {name = "zlua", ["x"] = 4, [1.0] = "one"}
print(h.name, h.x, h[1])
h.x = nil
print(h.x)

local k = {}
local general = {[k] = "table-key", [true] = "bool-key"}
print(general[k], general[true])

local nested = {inner = {answer = 42}}
print(nested.inner.answer)

local created = table.create(4, 2)
print(#created)
created[1] = "a"
created[2] = "b"
created.extra = "e"
print(#created, created[1], created.extra)

rawset(created, "raw", "r")
print(rawget(created, "raw"), rawget(created, "missing"))

local seen = {}
for key, value in pairs({a = 1, b = 2}) do
  seen[key] = value
end
print(seen.a, seen.b)

local out = {}
for index, value in ipairs({"x", "y", nil, "z"}) do
  out[index] = value
end
print(out[1], out[2], out[3], out[4])
