-- name: table/string_keys
-- category: table
-- expect: pass

local t = {}
for i = 1, 5000 do
  t["key" .. (i % 251)] = i
end

local sum = 0
for i = 0, 250 do
  sum = sum + t["key" .. i]
end
print(sum)
