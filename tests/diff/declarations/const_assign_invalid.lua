-- expect: pass
-- stage: resolve
-- feature: const-local
-- normalize: none

local value<const> = 1
value = 2
