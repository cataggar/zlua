-- expect: pass
-- stage: runtime
-- feature: control-flow
-- normalize: none

local x = 0
while x < 3 do
  x = x + 1
end

if x == 3 then
  print("if")
else
  print("else")
end

repeat
  x = x - 1
until x == 0

print(x)
