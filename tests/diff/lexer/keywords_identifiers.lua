-- expect: pass
-- stage: lex
-- feature: identifiers
-- normalize: none

local andromeda = true
global galaxy
if andromeda and not false then galaxy = nil end
