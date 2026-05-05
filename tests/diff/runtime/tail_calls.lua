-- expect: pass
-- stage: runtime
-- feature: tail-calls
-- normalize: none

function sum(n, acc)
  if n == 0 then
    return acc
  end
  return sum(n - 1, acc + n)
end

print(sum(1000, 0))

function id(...)
  return ...
end

function tail(...)
  return id(...)
end

print(tail("x", "y", "z"))
