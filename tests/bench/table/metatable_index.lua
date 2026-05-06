-- name: table/metatable_index
-- category: table
-- expect: pass

local fallback = { value = 17 }
local t = setmetatable({}, { __index = fallback })

local sum = 0
for i = 1, 50000 do
  sum = sum + t.value + (i % 5)
end
print(sum)
