-- expect: pass
-- stage: parse
-- feature: parser-expressions
-- normalize: none

local t = {
  1,
  2 + 3 * 4 ^ -5,
  name = "value",
  ['key'] = true,
  [1 << 2] = nil,
  function(a, ... rest) return a end,
}

local value = not false and (#"abc" == 3 or 1 | 2 ~ 3 & 4)
local text = "a" .. "b" .. "c"
local indexed = t.name + t[1]

(function(x)
  return x
end)(indexed)
