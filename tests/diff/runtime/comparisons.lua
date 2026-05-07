-- expect: pass
-- stage: runtime
-- feature: comparisons
-- normalize: none

print(1 == 1)
print(1 ~= 2)
print(1 < 2)
print(2 <= 2)
print("a" < "b")
print(not false)
print(not nil)
print(not 0)
print(true and "yes")
print(false or "fallback")

local mt = {
  __eq = function(a, b) return a.value == b.value end,
  __lt = function(a, b) return a.value < b.value end,
  __le = function(a, b) return a.value <= b.value end,
}

local function box(value)
  return setmetatable({value = value}, mt)
end

if box(1) == box(1) then print("eq branch") end
if box(1) ~= box(2) then print("ne branch") end
if box(1) < box(2) then print("lt branch") end
if box(2) <= box(2) then print("le branch") end
if box(3) > box(2) then print("gt branch") end
if box(3) >= box(3) then print("ge branch") end
if not (box(1) == box(2)) then print("not eq branch") end

local yielding_mt = {
  __lt = function(a, b)
    coroutine.yield("yield lt")
    return a.value < b.value
  end,
}

local co = coroutine.create(function()
  if setmetatable({value = 1}, yielding_mt) < setmetatable({value = 2}, yielding_mt) then
    print("yield branch")
  end
  return "done"
end)

print(coroutine.resume(co))
print(coroutine.resume(co))
