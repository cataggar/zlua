-- name: gc/collectgarbage_cycles
-- category: gc
-- expect: pass

local checksum = 0
for round = 1, 30 do
  local t = {}
  for i = 1, 1000 do
    t[i] = { i, "value" .. i }
  end
  checksum = checksum + #t + #t[round]
  collectgarbage()
end
print(checksum)
