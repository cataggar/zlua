-- name: string/sub_loop
-- category: string
-- expect: pass

local source = string.rep("abcdefghijklmnopqrstuvwxyz", 200)
local sum = 0
for i = 1, 20000 do
  local start = (i % 5000) + 1
  sum = sum + #string.sub(source, start, start + 7)
end
print(sum)
