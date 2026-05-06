-- name: stdlib/table_sort
-- category: stdlib
-- expect: pass

local checksum = 0
for round = 1, 80 do
  local t = {}
  for i = 1, 120 do
    t[i] = (i * 37 + round * 11) % 1009
  end
  table.sort(t)
  checksum = checksum + t[1] + t[#t]
end
print(checksum)
