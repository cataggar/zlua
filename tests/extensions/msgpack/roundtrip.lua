local input = {
    name = "app",
    features = {"json", "toml", "msgpack"},
    meta = {enabled = true, count = 3, ratio = 0.5},
    none = msgpack.null,
}

local bytes = msgpack.write(input)
local parsed = msgpack.read(bytes)

print(type(bytes), #bytes > 0)
print(parsed.name, parsed.meta.enabled, parsed.meta.count, parsed.meta.ratio)
print(parsed.features[1], parsed.features[2], parsed.features[3], parsed.none == msgpack.null)
