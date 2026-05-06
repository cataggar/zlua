-- expect: pass
-- stage: stdlib
-- feature: load-errors
-- normalize: none

local function check(source, needle)
  local f, msg = load(source)
  print(f == nil, string.find(msg, needle, 1, true) ~= nil)
end

check("local a = {4\n\n", "'}' expected")
check("syntax error", "near 'error'")
check("1e+", "malformed number")
check("::A::\n::A::", "label 'A' already defined")
check("local a<close>, b<close>", "multiple to-be-closed variables")

local _, msg = load("?", "=literal")
print(string.find(msg, "literal:1:", 1, true) == 1)

_, msg = load("?", "@path/to/chunk.lua")
print(string.find(msg, "path/to/chunk.lua:1:", 1, true) == 1)

_, msg = load("?", "@" .. string.rep("a", 80) .. ".lua")
print(string.find(msg, "...", 1, true) == 1)
