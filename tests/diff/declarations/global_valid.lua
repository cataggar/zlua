-- expect: pass
-- stage: resolve
-- feature: global-decl
-- normalize: none

global x, f
global<const> c, obj = 1, {}

x = c

function obj.inner()
  return c
end

function f(a, ... rest)
  local y = a + c
  return rest[1], y
end

do
  global *
  y = 2
end
