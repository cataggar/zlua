-- expect: pass
-- stage: stdlib
-- feature: argument-error-diagnostics
-- normalize: none

local function check(fn, ...)
  local ok, err = pcall(fn, ...)
  print(ok, err)
end

check(type)
check(math.sin, "x")
check(string.rep, "a", 1.5)
check(table.move, {}, "x", 1, 1)

local named = setmetatable({}, {__name = "NamedThing"})
check(math.sin, named)

local file = io.tmpfile()
check(math.sin, file)
