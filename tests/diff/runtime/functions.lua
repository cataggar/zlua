-- expect: pass
-- stage: runtime
-- feature: functions
-- normalize: none

function add(a, b)
  return a + b
end

local function id(value)
  return value
end

local literal = function(a, b)
  return a * b
end

print(add(2, 3))
print(id("local"))
print(literal(4, 5))

function twice(value)
  return add(value, value)
end

print(twice(add(1, 2)))

function fact(n)
  if n == 0 then
    return 1
  end
  return n * fact(n - 1)
end

print(fact(6))

local obj = {base = 10}
function obj:add(value)
  return self.base + value
end

print(obj:add(7))
print(obj.add(obj, 8))

function args(a, b)
  print(a, b)
end

args(1)
args(1, 2, 3)

function none()
end

function many()
  return 11, 12
end

local missing = none()
local first = many()
print(missing == nil, first)
print(tostring(123), tostring(nil))
