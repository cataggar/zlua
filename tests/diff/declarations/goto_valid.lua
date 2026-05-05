-- expect: pass
-- stage: resolve
-- feature: goto
-- normalize: none

goto done
local hidden = 1
::done::

while true do
  break
end
