-- expect: pass
-- stage: stdlib
-- feature: system-libraries
-- normalize: none

print(type(io), type(os), type(package), type(debug))
io.write("io", " ", 12, "\n")

local file = assert(io.open("tests/fixtures/system_input.txt", "r"))
print(io.type(file))
print(file:read("*l"))
print(file:read("*a"))
print(file:close())
print(io.type(file))

local chunk = assert(loadfile("tests/fixtures/system_loaded.lua"))
print(chunk())
print(dofile("tests/fixtures/system_dofile.lua"))
print(require("tests.fixtures.system_module"))
print(require("tests.fixtures.system_module"))
print(package.path ~= nil, type(package.searchers), type(package.searchers[1]), type(package.searchers[2]))

print(os.date("!%Y-%m-%d %H:%M:%S", 0))
local parts = os.date("!*t", 0)
print(parts.year, parts.month, parts.day, parts.hour, parts.min, parts.sec, parts.wday, parts.yday, parts.isdst)
print(os.getenv("__ZLUA_MILESTONE18_SHOULD_NOT_EXIST__") == nil)

local info = debug.getinfo(function() end)
print(type(info), info.what, type(info.currentline))
print(debug.traceback("msg", 2) ~= nil)
