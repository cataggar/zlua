-- expect: pass
-- stage: parse
-- feature: parser-returns
-- normalize: none

local function empty()
  return;
end

local function many()
  return 1, 2, 3
end

return many()
