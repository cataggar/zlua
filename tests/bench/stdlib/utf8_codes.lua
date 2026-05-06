-- name: stdlib/utf8_codes
-- category: stdlib
-- expect: pass

local source = string.rep("a\226\130\172z", 1000)
local sum = 0
for pos, code in utf8.codes(source) do
  sum = sum + pos + code
end
print(sum)
