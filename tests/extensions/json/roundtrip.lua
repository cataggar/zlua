local input = json.read('{"name":"app","features":["json","toml"],"meta":{"enabled":true,"count":2},"none":null}')
local text = json.write(input)
local parsed = json.read(text)

print(text:find('"features"') ~= nil, text:find('null') ~= nil)
print(parsed.name, parsed.meta.enabled, parsed.meta.count)
print(parsed.features[1], parsed.features[2], parsed.none == json.null)
