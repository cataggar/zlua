-- name: vm/upvalues
-- category: vm
-- expect: pass

local function make_counter(seed)
  local value = seed
  return function(delta)
    value = value + delta
    return value
  end
end

local counter = make_counter(11)
local sum = 0
for i = 1, 30000 do
  sum = (sum + counter(i % 9)) % 1000003
end
print(sum)
