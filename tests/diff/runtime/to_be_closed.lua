-- expect: pass
-- stage: runtime
-- feature: to-be-closed
-- normalize: none

local function closer(name, fail)
  return setmetatable({name = name}, {
    __close = function(self, err)
      print("close", self.name, err ~= nil)
      if fail then
        error("close-error-" .. self.name, 0)
      end
    end,
  })
end

do
  local x<close> = closer("scope")
  print("in-scope")
end

do
  local a<close> = closer("order-a")
  local b<close> = closer("order-b")
  print("in-order")
end

local function return_exit()
  local x<close> = closer("return")
  return "return-value"
end

print(return_exit())

while true do
  local x<close> = closer("break")
  break
end

do
  local x<close> = closer("goto")
  goto after_close
end
::after_close::

local ok_error, msg_error = pcall(function()
  local x<close> = closer("error")
  error("body-error", 0)
end)
print(ok_error, msg_error ~= nil)

local ok_close, msg_close = pcall(function()
  local x<close> = closer("close-fail", true)
end)
print(ok_close, msg_close ~= nil)

local ok_chain, msg_chain = pcall(function()
  local a<close> = closer("chain-a")
  local b<close> = closer("chain-b", true)
  error("chain-body", 0)
end)
print(ok_chain, msg_chain ~= nil)

local ok_bad, msg_bad = pcall(function()
  local x<close> = {}
end)
print(ok_bad, msg_bad ~= nil)

do
  local n<close> = nil
end

do
  local f<close> = false
end

print("nil-false-ok")
