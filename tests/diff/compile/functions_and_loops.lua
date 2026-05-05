-- expect: pass
-- stage: compile
-- feature: compiler-functions
-- normalize: none

global pairs

local total = 0

local function add(x)
  total = total + x
  return total
end

for i = 1, 3 do
  add(i)
end

while total < 10 do
  total = total + 1
  if total == 8 then break end
end

for k, v in pairs({one = 1, two = 2}) do
  total = total + v
end

return total
