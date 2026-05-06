-- expect: pass
-- stage: runtime
-- feature: errors
-- normalize: paths

local function normalize(err)
  local text = tostring(err)
  text = text:gsub("^.*name_aware_errors%.lua", "name_aware_errors.lua")
  text = text:gsub("^zlua", "name_aware_errors.lua")
  return text
end

local function report(label, fn)
  local ok, err = pcall(fn)
  print(label, ok)
  print(normalize(err))
end

report("global arithmetic", function()
  return bbbb + 1
end)

report("local call", function()
  local a = nil
  return a()
end)

local captured = true
report("upvalue length", function()
  return #captured
end)

report("field call", function()
  local t = {}
  return t.x()
end)

report("method call", function()
  local t = {}
  return t:bbbb()
end)

report("concat", function()
  return true .. "x"
end)

report("compare", function()
  return {} < 1
end)

report("for limit", function()
  for _ = 1, nil do
  end
end)

report("bitwise constant", function()
  return "a" & 1
end)
