local json = import("json")
local value = json.read('{"a":1,"b":[2]}')
print(json.write(value, { pretty = true, indent = 4 }))
