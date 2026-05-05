-- expect: pass
-- stage: runtime
-- feature: multiple-returns
-- normalize: none

function many()
  return 10, 20, 30
end

function none()
end

local a, b, c, d = many()
print(a, b, c, d)

local e, f, g = 1, many()
print(e, f, g)

local h, i = many(), 40
print(h, i)

print("args", many())
print("middle", many(), 40)
print("none", none(), 50)

local t = {0, many()}
print(#t, t[1], t[2], t[3], t[4])

local u = {many(), 40}
print(#u, u[1], u[2])
