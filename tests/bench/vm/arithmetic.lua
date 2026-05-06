-- name: vm/arithmetic
-- category: vm
-- iterations: 1
-- warmup: 0
-- timeout-ms: 10000
-- expect: pass

local sum = 0
for i = 1, 10000 do
  sum = sum + i
end
print(sum)
