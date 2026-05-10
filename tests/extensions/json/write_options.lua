local compact = json.write({name = "Ada", nums = {1, 2, 3}}, {pretty = false})
local pretty = json.write(json.read('{"a":1,"b":[2]}'), {pretty = true, indent = 2})

print(compact)
print(pretty)

local ok_options, options_err = pcall(json.write, {}, "pretty")
local ok_pretty_type, pretty_type_err = pcall(json.write, {}, {pretty = "yes"})
local ok_indent_type, indent_type_err = pcall(json.write, {}, {indent = false})
local ok_indent_range, indent_range_err = pcall(json.write, {}, {indent = -1})

print(ok_options, tostring(options_err):find("table") ~= nil)
print(ok_pretty_type, tostring(pretty_type_err):find("boolean pretty") ~= nil)
print(ok_indent_type, tostring(indent_type_err):find("numeric indent") ~= nil)
print(ok_indent_range, tostring(indent_range_err):find("indent out of range") ~= nil)
