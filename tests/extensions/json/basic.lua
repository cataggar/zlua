local json = import("json")
print(type(json), type(package))

local value = json.read('{"name":"Ada","nums":[1,2,null],"ok":true}')
print(value.name, value.ok, value.nums[3] == json.null)
print(json.write(value))
