-- name: vm/function_calls
-- category: vm
-- expect: pass

local function step(a, b, c)
  return (a + b * 3 - c) % 1000003
end

local x = 1
for i = 1, 30000 do
  x = step(x, i, i % 17)
end
print(x)
