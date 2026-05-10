local inline = toml.write({meta = {name = "inline"}}, {layout = "inline"})
local inline_tables = toml.write({meta = {name = "inline_tables"}}, {layout = "inline_tables"})
local sections = toml.write({meta = {name = "sections"}}, {layout = "sections"})

print(inline)
print(inline_tables)
print(sections)

local ok_options, options_err = pcall(toml.write, {}, "sections")
local ok_layout_type, layout_type_err = pcall(toml.write, {}, {layout = true})

print(ok_options, tostring(options_err):find("table") ~= nil)
print(ok_layout_type, tostring(layout_type_err):find("string layout") ~= nil)
