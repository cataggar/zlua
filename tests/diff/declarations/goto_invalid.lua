-- expect: pass
-- stage: resolve
-- feature: goto
-- normalize: none

goto label
local hidden = 1
::label::
hidden = 2
