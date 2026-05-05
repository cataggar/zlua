-- expect: pass
-- stage: runtime
-- feature: errors
-- normalize: none

local function ok(a, b)
  return a + b, "sum"
end

print(pcall(ok, 2, 5))

local function fail()
  error("boom", 0)
end

print(pcall(fail))
print(assert("value", "extra"))

local ok_assert, err_assert = pcall(assert, false, "assert-message")
print(ok_assert, err_assert)

local ok_after, msg_after = pcall(function()
  local t = {a = 1}
  error("stop", 0)
  t.a = 2
end)
print(ok_after, msg_after)
print(pcall(function() return "after" end))

local function handler(err)
  return "handled:" .. err
end

print(xpcall(fail, handler))
print(xpcall(function(a, b) return a * b, "product" end, handler, 6, 7))

local ok_handler, handler_msg = xpcall(fail, function(err)
  error("handler:" .. err, 0)
end)
print(ok_handler, handler_msg)

local mt_index = setmetatable({}, {
  __index = function()
    error("index-error", 0)
  end,
})
print(pcall(function() return mt_index.missing end))

local mt_call = setmetatable({}, {
  __call = function()
    error("call-error", 0)
  end,
})
print(pcall(mt_call))

local ok_trace, trace = xpcall(function()
  error("trace-source", 0)
end, debug.traceback)
print(ok_trace, trace ~= nil, trace ~= "trace-source")

local ok_native, native_msg = pcall(rawget, nil, "x")
print(ok_native, native_msg ~= nil)

local ok_level, level_msg = pcall(function()
  error("level-two", 2)
end)
print(ok_level, level_msg ~= nil)
