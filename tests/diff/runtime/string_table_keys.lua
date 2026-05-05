-- expect: pass
-- stage: runtime
-- feature: string-table-keys
-- normalize: none

local t = {}
t["hello"] = "world"
t.a = 1
t["a"] = t["a"] + 1
t[1.0] = "one"
print(t["hello"])
print(t.a)
print(t["a"])
print(t[1])
local key = "he" .. "llo"
print(t[key])
t[key] = nil
print(t.hello)
