-- expect: pass
-- stage: runtime
-- feature: numbers
-- normalize: none

print(9223372036854775807)
print(0xffffffffffffffff)
print(0x8000000000000000)
print(0x1p4)
print(0x1.8p+2)
print("2" + "3")
print("2.0" + 1)
print("0x10" + 1)
print("0x1.8p+2" + 1)
print(5 / 2)
print(5 // 2)
print(5.0 // 2)
print(7 % 4)
print(4.0 % 1.5)
