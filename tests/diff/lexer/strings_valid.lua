-- expect: pass
-- stage: lex
-- feature: strings
-- normalize: none

local values = {
  'short', "double", '\n', '\x41', '\255', '\u{41}', [=[long string]=]
}
