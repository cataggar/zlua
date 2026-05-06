-- name: table/array_writes
-- category: table
-- expect: pass

local t = {}
for i = 1, 1000 do
  t[i] = 0
end

for i = 1, 80000 do
  local index = (i % 1000) + 1
  t[index] = t[index] + i
end

local sum = 0
for i = 1, 1000 do
  sum = sum + t[i]
end
print(sum)
