-- expect: pass
-- stage: runtime
-- feature: official-attrib-core
-- normalize: none

assert(require("string") == string)
assert(require("math") == math)
assert(type(package.config) == "string")

do
  local path = string.rep("?", 20)
  local found, err = package.searchpath("xuxu", path)
  assert(not found and string.find(err, string.rep("xuxu", 20)))
end

do
  local sum = 0
  for i = 1, 3 do sum = sum + i end
  assert(sum == 6)
end

do
  local function f() return 10, 11, 12 end
  local a, b = f(), 1, 2, f()
  assert(a == 10 and b == 1)
end

do
  local a, i, j, b
  a = {"a", "b"}; i = 1; j = 2; b = a
  i, a[i], a, j, a[j], a[i + j] = j, i, i, b, j, i
  assert(i == 2 and b[1] == 1 and a == 1 and j == b and b[2] == 2 and b[3] == 1)
end

do
  local function foo()
    local _ENV <const> = 11
    X = "hi"
  end
  local ok, msg = pcall(foo)
  assert(not ok and string.find(msg, "number"))
end

do
  local maxint = math.maxinteger
  while maxint ~= (maxint + 0.0) or (maxint - 1) ~= (maxint - 1.0) do
    maxint = maxint // 2
  end
  local maxintF = maxint + 0.0
  local a = {}
  a[maxintF] = 10; a[maxintF - 1.0] = 11
  assert(a[maxint] == 10 and a[maxint - 1] == 11)
end

print("ok")
