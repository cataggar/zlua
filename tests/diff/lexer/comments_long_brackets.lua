-- expect: pass
-- stage: lex
-- feature: comments
-- normalize: none

-- short comment
--[=[ long comment ]=]
local value = [==[
long string
]==]
