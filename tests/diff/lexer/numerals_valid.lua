-- expect: pass
-- stage: lex
-- feature: numeric-literals
-- normalize: none

local values = {
  0, 123, 1.25, .5, 1e-3, 0xff, 0x1p4, 0x1.8p+2
}
