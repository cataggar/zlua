-- expect: pass
-- stage: stdlib
-- feature: resolver-error-diagnostics
-- normalize: none

local function contains(text, needle)
  return string.find(text, needle, 1, true) ~= nil
end

local function check(source, ...)
  local f, msg = load(source)
  print(f == nil)
  for i = 1, select("#", ...) do
    print(contains(msg, select(i, ...)))
  end
end

check("::A::\n::A::", "label 'A' already defined")
check("goto A\ndo local x ::A:: end", "no visible label 'A'", "line 1")
check("break", "break outside loop")
check("local x<const> = 1\nx = 2", "attempt to assign to const variable 'x'")
check("local x<unknown> = 1", "unknown attribute 'unknown'")
