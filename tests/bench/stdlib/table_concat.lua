-- name: stdlib/table_concat
-- category: stdlib
-- expect: pass

local t = {}
for i = 1, 2000 do
  t[i] = "x" .. (i % 10)
end

local sum = 0
for i = 1, 1000 do
  sum = sum + #table.concat(t, ",")
end
print(sum)
