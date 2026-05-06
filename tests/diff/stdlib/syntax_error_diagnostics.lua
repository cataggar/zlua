-- expect: pass
-- stage: stdlib
-- feature: syntax-error-diagnostics
-- normalize: none

local function contains(text, needle)
  return string.find(text, needle, 1, true) ~= nil
end

local function check(source, source_name, ...)
  local f, msg = load(source, source_name)
  print(f == nil)
  for i = 1, select("#", ...) do
    print(contains(msg, select(i, ...)))
  end
end

check("local a = {4\n\n", nil, "'}' expected (to close '{' at line 1)", "near <eof>")
check("1e+", nil, "malformed number", "near '1e+'")
check("'unterminated", "=literal", "literal:1:", "unfinished string")

local long_name = "@" .. string.rep("a", 80) .. ".lua"
local _, long_msg = load("?", long_name)
print(string.find(long_msg, "...", 1, true) == 1)
print(contains(long_msg, ":1: syntax error near '?'"))
