-- expect: pass
-- stage: runtime
-- feature: errors
-- normalize: none

local pcall_object = { tag = "pcall" }
local ok, err = pcall(function()
  error(pcall_object, 0)
end)
print(ok, err == pcall_object, err.tag)

ok, err = pcall(function()
  error("plain", 0)
end)
print(ok, err)

local handler_arg = nil
local xpcall_object = { tag = "xpcall" }
local xok, handled = xpcall(function()
  error(xpcall_object, 0)
end, function(value)
  handler_arg = value
  collectgarbage()
  return value
end)
print(xok, handled == xpcall_object, handler_arg == xpcall_object, handled.tag)

local resume_object = { tag = "resume" }
local co = coroutine.create(function()
  error(resume_object, 0)
end)
ok, err = coroutine.resume(co)
collectgarbage()
print(ok, err == resume_object, err.tag)

local wrap_object = { tag = "wrap" }
local wrapped = coroutine.wrap(function()
  error(wrap_object, 0)
end)
ok, err = pcall(wrapped)
collectgarbage()
print(ok, err == wrap_object, err.tag)

local assert_object = { tag = "assert" }
ok, err = pcall(assert, false, assert_object)
print(ok, err == assert_object, err.tag)
