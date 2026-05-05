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
