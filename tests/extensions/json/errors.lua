local json = import("json")

local ok_read, read_err = pcall(json.read, '{bad')
local cyclic = {}
cyclic.self = cyclic
local ok_cycle, cycle_err = pcall(json.write, cyclic)
local ok_import, import_err = pcall(import, "missing")

print(ok_read, tostring(read_err):find("json.read") ~= nil)
print(ok_cycle, tostring(cycle_err):find("cyclic") ~= nil)
print(ok_import, tostring(import_err):find("module 'missing' not found") ~= nil)
