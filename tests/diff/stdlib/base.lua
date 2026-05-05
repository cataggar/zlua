-- expect: pass
-- stage: stdlib
-- feature: stdlib-base
-- normalize: none

print(_VERSION)
print(type(nil), type(false), type(1), type(1.5), type("x"), type({}), type(function() end), type(coroutine.create(function() end)))
print(tonumber("42"), tonumber("ff", 16), tonumber("bad") == nil)
print(pcall(warn, "quiet"))
