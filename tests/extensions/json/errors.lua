local ok_read, read_err = pcall(json.read, '{bad')
local cyclic = {}
cyclic.self = cyclic
local ok_cycle, cycle_err = pcall(json.write, cyclic)

print(ok_read, tostring(read_err):find("json.read") ~= nil)
print(ok_cycle, tostring(cycle_err):find("cyclic") ~= nil)
