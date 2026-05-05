-- expect: pass
-- stage: resolve
-- feature: vararg-decl
-- normalize: none

function f(... rest)
  rest = 1
end
