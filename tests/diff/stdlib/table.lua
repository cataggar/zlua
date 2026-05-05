-- expect: pass
-- stage: stdlib
-- feature: stdlib-table
-- normalize: none

local t = {"b", "c"}
table.insert(t, 1, "a")
table.insert(t, "d")
print(table.concat(t, ","))
print(table.remove(t, 2), table.concat(t, ""))

local moved = table.move(t, 1, 3, 2, {})
print(moved[1], moved[2], moved[3], moved[4])

local packed = table.pack("x", nil, "z")
print(packed.n, packed[1], packed[2] == nil, packed[3])
print(table.unpack({10, 20, 30}, 2, 3))

local sorted = {3, 1, 2}
table.sort(sorted)
print(table.concat(sorted, ":"))
table.sort(sorted, function(a, b) return a > b end)
print(table.concat(sorted, ":"))
print(#table.create(3, 1))
