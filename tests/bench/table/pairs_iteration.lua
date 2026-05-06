-- name: table/pairs_iteration
-- category: table
-- expect: pass

local t = {}
for i = 1, 2000 do
  t["k" .. i] = i
end

local sum = 0
for _ = 1, 50 do
  for _, value in pairs(t) do
    sum = sum + value
  end
end
print(sum)
