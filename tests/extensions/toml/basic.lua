print(type(toml), type(import), type(package))

local value = toml.read([[name = "Ada"
ok = true
nums = [1, 2, 3]
date = 2026-05-09

[owner]
name = "Grace"
]])

print(value.name, value.ok, value.nums[2])
print(value.owner.name, value.date)
print(toml.write({name = "Ada", ok = true, nums = {1, 2, 3}}))
print(toml.write({name = "app", database = {host = "localhost", port = 5432}, servers = {{host = "one", port = 1}, {host = "two", port = 2}}}, {layout = "sections"}))
