-- expect: pass
-- stage: runtime
-- feature: metatables
-- normalize: none

local mt = {}
local t = setmetatable({own = "own"}, mt)
print(getmetatable(t) == mt)

mt.__index = {fallback = "table-index"}
print(t.own, t.fallback, rawget(t, "fallback"))

mt.__index = function(self, key)
  return "function-index:" .. key
end
print(t.missing)

local writes = {}
mt.__newindex = writes
t.created = "via-table"
print(t.created, writes.created)

mt.__newindex = function(self, key, value)
  writes[key] = "function-newindex:" .. value
end
t.other = "value"
print(t.other, writes.other)

local callable = setmetatable({base = 7}, {
  __call = function(self, a, b)
    return self.base + a + b
  end,
})
print(callable(2, 3))
local function tail_call(a, b)
  return callable(a, b)
end
print(tail_call(4, 5))

local named = setmetatable({}, {
  __tostring = function(self)
    return "named-table"
  end,
})
print(tostring(named), named)

local sized = setmetatable({1, 2, 3}, {
  __len = function(self)
    return 99
  end,
})
print(#sized, rawlen(sized))

local function boxed(value)
  return setmetatable({value = value}, {
    __add = function(a, b) return boxed(a.value + b.value) end,
    __sub = function(a, b) return boxed(a.value - b.value) end,
    __mul = function(a, b) return boxed(a.value * b.value) end,
    __div = function(a, b) return boxed(a.value / b.value) end,
    __idiv = function(a, b) return boxed(a.value // b.value) end,
    __mod = function(a, b) return boxed(a.value % b.value) end,
    __pow = function(a, b) return boxed(a.value ^ b.value) end,
    __unm = function(a) return boxed(-a.value) end,
    __band = function(a, b) return boxed(a.value & b.value) end,
    __bor = function(a, b) return boxed(a.value | b.value) end,
    __bxor = function(a, b) return boxed(a.value ~ b.value) end,
    __shl = function(a, b) return boxed(a.value << b.value) end,
    __shr = function(a, b) return boxed(a.value >> b.value) end,
    __bnot = function(a) return boxed(~a.value) end,
    __concat = function(a, b) return "concat:" .. a.value .. ":" .. b.value end,
    __eq = function(a, b) return a.value == b.value end,
    __lt = function(a, b) return a.value < b.value end,
    __le = function(a, b) return a.value <= b.value end,
  })
end

local a = boxed(6)
local b = boxed(3)
print((a + b).value, (a - b).value, (a * b).value)
print((a / b).value, (a // b).value, (a % b).value, (a ^ b).value)
print((-a).value, (a & b).value, (a | b).value, (a ~ b).value)
print((a << b).value, (a >> b).value, (~b).value)
print(a .. b)
print(a == boxed(6), a == b, a < b, b < a, a <= boxed(6), b <= a)

local raw = setmetatable({x = 1}, {
  __index = function() return 2 end,
  __newindex = function() error("should not run") end,
  __len = function() return 10 end,
  __eq = function() return true end,
})
rawset(raw, "y", 3)
print(rawget(raw, "x"), rawget(raw, "missing"), raw.y, rawlen(raw))
print(rawequal(raw, raw), rawequal(raw, setmetatable({}, getmetatable(raw))))

local locked = setmetatable({}, {__metatable = "locked"})
print(getmetatable(locked))

local string_mt = getmetatable("")
print(type(string_mt), string_mt.__index == string, ("abc"):sub(2))
