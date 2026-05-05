-- expect: pass
-- stage: compile
-- feature: compiler-basic
-- normalize: none

global print

local a = 1 + 2 * 3
local b = "hello" .. " world"
local t = {a, name = b, [a] = true}

if a > 3 then
  t.name = b
else
  t[a] = nil
end

return t
