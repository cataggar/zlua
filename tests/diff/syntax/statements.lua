-- expect: pass
-- stage: parse
-- feature: parser-statements
-- normalize: none

;
global x, y
global<const> *

local a<const>, b<close> = 1, 2

function obj.inner:method(a, b, ... rest)
  if a then
    b = b + 1
  elseif b then
    b = 2
  else
    b = 3
  end

  while b do
    break
  end

  repeat
    b = b - 1
  until b == 0

  for i = 1, 10, 2 do
    ;
  end

  for k, v in pairs({}) do
    do
      local nested = k
    end
  end

  ::again::
  goto again

  return b
end

local function lf()
  return
end

obj.inner:method(1, 2, 3)
