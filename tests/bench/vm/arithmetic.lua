-- name: vm/arithmetic
-- category: vm
-- expect: pass

local sum = 0
for i = 1, 10000 do
  sum = sum + i
end
print(sum)
