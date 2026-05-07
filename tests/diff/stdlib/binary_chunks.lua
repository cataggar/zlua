-- expect: pass
-- stage: stdlib
-- feature: binary-chunks
-- normalize: none

local source = [[
  return function(seed)
    local total = seed
    local function add(value)
      total = total + value
      return total
    end
    return add
  end
]]

local factory = assert(load(string.dump(assert(load(source)))))()
local add = factory(10)
print(add(2), add(3))

local dumped = string.dump(assert(load("return 40 + ...")))
local f = assert(load(dumped, "chunk", "b", {}))
print(f(2))

local text_only, text_only_message = load(dumped, "chunk", "t")
print(text_only == nil, string.find(text_only_message, "binary chunk") ~= nil)

local debug = require "debug"
local secret = 12
local stripped = assert(load(string.dump(function() return secret end, true)))
local upvalue_name = debug.getupvalue(stripped, 1)
print(upvalue_name)
print(debug.getinfo(stripped).currentline)

local foreign, foreign_message = load("\27Lua\85\0\25\147\13\10\26\10foreign")
print(foreign == nil, foreign_message ~= nil)
