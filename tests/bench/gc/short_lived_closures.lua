-- name: gc/short_lived_closures
-- category: gc
-- expect: pass

local sum = 0
for i = 1, 20000 do
  local base = i % 97
  local function f(value)
    return base + value
  end
  sum = sum + f(i % 11)
end
print(sum)
