-- expect: pass
-- stage: runtime
-- feature: gc
-- normalize: none

local weak_values = setmetatable({}, { __mode = "v" })
do
  local value = { name = "dead-value" }
  weak_values.item = value
end
collectgarbage("collect")
print(weak_values.item == nil)

local weak_keys = setmetatable({}, { __mode = "k" })
do
  local key = {}
  weak_keys[key] = "dead-key"
end
collectgarbage("collect")
local count = 0
for k, v in pairs(weak_keys) do
  count = count + 1
end
print(count)

local ephemeron = setmetatable({}, { __mode = "k" })
local key = {}
ephemeron[key] = { answer = 42 }
collectgarbage("collect")
print(ephemeron[key].answer)

key = nil
collectgarbage("collect")
count = 0
for k, v in pairs(ephemeron) do
  count = count + 1
end
print(count)
