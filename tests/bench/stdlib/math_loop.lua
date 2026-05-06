-- name: stdlib/math_loop
-- category: stdlib
-- expect: pass

local sum = 0
for i = 1, 20000 do
  sum = sum + math.floor(math.sqrt(i * 3)) + math.abs((i % 17) - 8)
end
print(sum)
