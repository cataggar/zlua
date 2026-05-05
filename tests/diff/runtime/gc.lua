-- expect: pass
-- stage: runtime
-- feature: gc
-- normalize: none

local keep = { answer = 42 }

local i = 1
while i <= 20 do
  local transient = { i, { value = i + 1 } }
  collectgarbage("collect")
  i = i + 1
end

collectgarbage("collect")
collectgarbage("step")

print(keep.answer)

do
  local dead = setmetatable({ name = "dead" }, {
    __gc = function(self)
      print("gc-final", self.name)
    end,
  })
  dead = nil
end

collectgarbage("collect")
collectgarbage("collect")
print("gc-ok")
