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
