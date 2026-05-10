local input = {
  name = "app",
  database = {host = "localhost", port = 5432},
  servers = {{host = "one", port = 1}, {host = "two", port = 2}},
}

local text = toml.write(input, {layout = "sections"})
local parsed = toml.read(text)

print(text:find("%[database%]") ~= nil, text:find("%[%[servers%]%]") ~= nil)
print(parsed.name, parsed.database.host, parsed.database.port)
print(parsed.servers[1].host, parsed.servers[2].port)
