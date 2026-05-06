-- name: table/array_reads
-- category: table
-- expect: pass

local t = {}
for i = 1, 1000 do
  t[i] = i * 3
end

local sum = 0
for i = 1, 80000 do
  local index = (i % 1000) + 1
  sum = sum + t[index]
end
print(sum)
