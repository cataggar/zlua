-- name: string/find_pattern
-- category: string
-- expect: pass

local source = string.rep("abc123xyz", 500)
local sum = 0
for i = 1, 8000 do
  local first, last = string.find(source, "%d%d%d", (i % 3000) + 1)
  sum = sum + (first or 0) + (last or 0)
end
print(sum)
