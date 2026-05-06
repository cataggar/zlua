-- name: string/gsub_replace
-- category: string
-- expect: pass

local source = string.rep("a1 b22 c333 ", 300)
local sum = 0
for i = 1, 300 do
  local out, count = string.gsub(source, "%d+", "#")
  sum = sum + #out + count
end
print(sum)
