-- expect: pass
-- stage: runtime
-- feature: closures
-- normalize: none

local function make_counter()
  local x = 0
  return function()
    x = x + 1
    return x
  end
end

local counter = make_counter()
print(counter())
print(counter())

local function make_pair()
  local x = 0
  return function()
    x = x + 1
    return x
  end, function()
    x = x + 10
    return x
  end
end

local inc, add10 = make_pair()
print(inc())
print(add10())
print(inc())

local outlived
do
  local value = "closed"
  outlived = function()
    return value
  end
end
do
  local value = "reused"
end
print(outlived())

local function outer(a)
  local b = 2
  return function(c)
    return function(d)
      b = b + 1
      return a + b + c + d
    end
  end
end

local middle = outer(10)
local inner = middle(20)
print(inner(30))
print(inner(30))

local function fact(n)
  if n == 0 then
    return 1
  end
  return n * fact(n - 1)
end

print(fact(5))
