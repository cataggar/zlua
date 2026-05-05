-- expect: pass
-- stage: runtime
-- feature: gc
-- normalize: none

print(collectgarbage("count") >= 0)
print(collectgarbage("isrunning"))
print(collectgarbage("stop"))
print(collectgarbage("isrunning"))
print(collectgarbage("step", 0))
print(collectgarbage("restart"))
print(collectgarbage("isrunning"))
print(collectgarbage("generational"))
print(collectgarbage("incremental"))
print(collectgarbage("generational"))
print(collectgarbage("param", "pause", 300))
print(collectgarbage("param", "pause"))
print(collectgarbage("param", "pause", 250))
