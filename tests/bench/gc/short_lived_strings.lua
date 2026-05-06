-- name: gc/short_lived_strings
-- category: gc
-- expect: pass

local sum = 0
for i = 1, 20000 do
  local s = "item:" .. i .. ":" .. (i % 17)
  sum = sum + #s
end
print(sum)
