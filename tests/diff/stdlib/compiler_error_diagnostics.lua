-- expect: pass
-- stage: stdlib
-- feature: compiler-error-diagnostics
-- normalize: none

local source = "return " .. string.rep("1,", 255) .. "1"
local f, msg = load(source)
print(f == nil)
print(type(msg) == "string")
print(string.find(msg, "too many", 1, true) ~= nil)
