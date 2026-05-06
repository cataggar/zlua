-- name: table/array_append
-- category: table
-- expect: pass

local t = {}
for i = 1, 30000 do
  t[#t + 1] = i % 97
end

local sum = 0
for i = 1, #t do
  sum = sum + t[i]
end
print(#t, sum)
