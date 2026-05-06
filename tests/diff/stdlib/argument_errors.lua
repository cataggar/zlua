-- expect: pass
-- stage: stdlib
-- feature: stdlib-argument-errors

local function check(fn, ...)
  local ok, err = pcall(fn, ...)
  print(ok, err)
end

check(type)
check(math.sin, "x")
check(string.format, "%d", {})
check(table.move, {}, "x", 1, 1)

local named = setmetatable({}, {__name = "NamedThing"})
check(math.sin, named)

local file = io.tmpfile()
check(math.sin, file)
