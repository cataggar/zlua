-- name: string/concat_growth
-- category: string
-- expect: pass

local s = ""
for i = 1, 2000 do
  s = s .. "a" .. (i % 10)
end
print(#s, string.byte(s, 1), string.byte(s, #s))
