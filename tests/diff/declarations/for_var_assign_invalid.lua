-- expect: pass
-- stage: resolve
-- feature: for-decl
-- normalize: none

for i = 1, 3 do
  i = 4
end
