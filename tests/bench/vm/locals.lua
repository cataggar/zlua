-- name: vm/locals
-- category: vm
-- expect: pass

local a, b, c, d = 1, 2, 3, 4
for i = 1, 60000 do
  a = b + i
  b = c + a
  c = d + b
  d = a + c
end
print((a + b + c + d) % 1000000007)
