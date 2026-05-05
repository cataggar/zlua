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
