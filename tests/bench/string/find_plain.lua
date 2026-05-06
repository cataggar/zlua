-- name: string/find_plain
-- category: string
-- expect: pass

local source = string.rep("abcxyz", 1000) .. "needle"
local sum = 0
for i = 1, 10000 do
  local found = string.find(source, "needle", 1, true)
  sum = sum + found
end
print(sum)
