-- expect: pass
-- stage: runtime
-- feature: coroutine
-- normalize: none

local co = coroutine.create(function(a, b)
  print("start", a, b, coroutine.status(coroutine.running()))
  local r1, r2 = coroutine.yield("yield-1", a + b)
  print("resumed", r1, r2)

  local function nested(x)
    return coroutine.yield("nested", x)
  end

  print("nested-return", nested("narg"))
  return "done", 99
end)

print("initial", coroutine.status(co))
print("resume1", coroutine.resume(co, 2, 3))
print("after-yield", coroutine.status(co))
print("resume2", coroutine.resume(co, "r1", "r2"))
print("after-yield2", coroutine.status(co))
print("resume3", coroutine.resume(co, "back"))
print("after-dead", coroutine.status(co))

local ok_dead, err_dead = coroutine.resume(co)
print("dead", ok_dead, err_dead ~= nil)

local wrapped = coroutine.wrap(function(x)
  print("wrap-start", x)
  local y = coroutine.yield("wrap-yield")
  print("wrap-resume", y)
  error("wrap-boom", 0)
end)

print("wrap1", wrapped("wx"))
local wrap_ok, wrap_msg = pcall(wrapped, "wy")
print("wrap2", wrap_ok, wrap_msg ~= nil)

local co_err = coroutine.create(function()
  error("co-boom", 0)
end)

local ok_err, msg_err = coroutine.resume(co_err)
print("resume-error", ok_err, msg_err ~= nil, coroutine.status(co_err))

local co_pcall = coroutine.create(function()
  print("pcall-success", pcall(function(a)
    return a, "ok"
  end, 7))
  print("pcall-fail", pcall(function()
    error("pcall-boom", 0)
  end))
end)

print("pcall-co", coroutine.resume(co_pcall))

local co_in_pcall = coroutine.create(function()
  return "inside-pcall"
end)

print("resume-in-pcall", pcall(coroutine.resume, co_in_pcall))

local function closer(name)
  return setmetatable({ name = name }, {
    __close = function(self, err)
      print("close", self.name, err ~= nil)
    end,
  })
end

local co_close = coroutine.create(function()
  local x<close> = closer("co-close")
  coroutine.yield("co-yield")
  return "co-done"
end)

print("close-resume1", coroutine.resume(co_close))
print("close-resume2", coroutine.resume(co_close))
