-- expect: pass
-- stage: runtime
-- feature: strings
-- normalize: none

print("a" .. "b" .. "c")
print("x" .. 12 .. "y")
print(1 .. " + " .. 2.5)
print("A\x42\67")
print("a\z   
  b")
print("\u{41}")
print([=[long]=])
print(#"abc")
print("same" == "sa" .. "me")
print(tostring(nil))
print(tostring(true))
print(tostring(1))
print(tostring(1.5))
print(tostring("x"))
