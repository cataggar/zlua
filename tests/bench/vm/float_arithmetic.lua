-- name: vm/float_arithmetic
-- category: vm
-- expect: pass

local x = 0.5
for i = 1, 20000 do
  x = x + i * 0.125
  x = x - i * 0.0625
end
print(string.format("%.3f", x))
