local ok_read, read_err = pcall(msgpack.read, string.char(0xc1))
local ok_trailing, trailing_err = pcall(msgpack.read, string.char(0xc0, 0xc0))
local cyclic = {}
cyclic.self = cyclic
local ok_cycle, cycle_err = pcall(msgpack.write, cyclic)
local sparse = {1, nil, 3}
local ok_sparse, sparse_err = pcall(msgpack.write, sparse)

print(ok_read, tostring(read_err):find("msgpack.read") ~= nil)
print(ok_trailing, tostring(trailing_err):find("Trailing") ~= nil)
print(ok_cycle, tostring(cycle_err):find("cyclic") ~= nil)
print(ok_sparse, tostring(sparse_err):find("nil hole") ~= nil)
