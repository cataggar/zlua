-- expect: pass
-- stage: runtime
-- feature: varargs
-- normalize: none

function named(a, ... rest)
  print(a, rest.n, rest[1], rest[2], rest[3])
end

named(10, 20, 30)

function collect(...)
  print(select("#", ...))
  print(select(1, ...))
  print(select(2, ...))
  print(select(-1, ...))
end

collect("a", "b", "c")

function forward(...)
  return ...
end

print(forward(1, 2, 3))

function append(...)
  return 0, ...
end

print(append(4, 5))

function mutate_named(... rest)
  rest[1] = 11
  rest[5] = 24
  rest.n = 5
  return ...
end

local packed = table.pack(mutate_named(1, 2, 3, nil, 4))
print(packed.n, packed[1], packed[2], packed[3], packed[4], packed[5])

function shrink_named(... rest)
  rest.n = 0
  return (...)
end

print(shrink_named(42) == nil)

local f, message = load("return function (... rest) rest = 1 end")
print(f == nil, string.find(message, "const variable 'rest'", 1, true) ~= nil)
