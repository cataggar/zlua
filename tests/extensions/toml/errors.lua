local ok_read, read_err = pcall(toml.read, 'name =')
local ok_write, write_err = pcall(toml.write, toml.read('value = 1').missing)
local ok_options, options_err = pcall(toml.write, {}, {layout = "bad"})

print(ok_read, tostring(read_err):find("toml.read") ~= nil)
print(ok_write, tostring(write_err):find("toml.write") ~= nil)
print(ok_options, tostring(options_err):find("layout") ~= nil)
