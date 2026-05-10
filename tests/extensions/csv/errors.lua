local ok_read, read_err = pcall(csv.read, "\"unterminated")
local ok_shape, shape_err = pcall(csv.write, {1, 2, 3})
local ok_extra, extra_err = pcall(csv.write, {{a = 1}, {a = 2, b = 3}})

local cyclic = {}
cyclic[1] = cyclic
local ok_cycle, cycle_err = pcall(csv.write, cyclic)

print(ok_read, tostring(read_err):find("csv.read") ~= nil)
print(ok_shape, tostring(shape_err):find("csv.write") ~= nil)
print(ok_extra, tostring(extra_err):find("csv.write") ~= nil)
print(ok_cycle, tostring(cycle_err):find("csv.write") ~= nil)
