-- expect: pass
-- stage: runtime
-- feature: runtime-type-error-diagnostics
-- normalize: paths

local function normalize(err)
  return tostring(err):gsub("^.*type_error_diagnostics%.lua", "type_error_diagnostics.lua")
end

local function check(label, fn, ...)
  local ok, err = pcall(fn)
  print(label, ok)
  local text = normalize(err)
  for i = 1, select("#", ...) do
    print(string.find(text, select(i, ...), 1, true) ~= nil)
  end
end

check("arith global", function() return missing_name + 1 end, "arithmetic", "global 'missing_name'")
check("call local", function() local f = nil; return f() end, "call a nil value", "local 'f'")
check("field call", function() local t = {}; return t.x() end, "call a nil value", "field 'x'")
check("same compare", function() return print < print end, "compare two function values")
check("mixed compare", function() return print < 1 end, "compare function with number")
check("length", function() return #print end, "length of a function value")
check("for file", function() for _ = io.stdin, 10 do end end, "initial value", "FILE")
