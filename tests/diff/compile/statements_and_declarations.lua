-- expect: pass
-- stage: compile
-- feature: compiler-statements
-- normalize: none

global t, pairs
global<const> c = 1

t = {}

function t.inner:method(a, ... rest)
  local value = a + c
  repeat
    value = value - 1
  until value <= 0
  ::again::
  do
    local shadow = rest[1]
    if shadow then goto done end
  end
  goto again
  ::done::
  return value
end

for k, v in pairs({one = 1}) do
  t[k] = v
end
