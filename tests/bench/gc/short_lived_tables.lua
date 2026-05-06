-- name: gc/short_lived_tables
-- category: gc
-- expect: pass

local sum = 0
for i = 1, 30000 do
  local t = { i, i + 1, tag = i % 13 }
  sum = sum + t[1] + t[2] + t.tag
end
print(sum)
