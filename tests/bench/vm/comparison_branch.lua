-- name: vm/comparison_branch
-- category: vm
-- expect: pass

local score = 0
for i = 1, 50000 do
  if i % 3 == 0 then
    score = score + 7
  elseif i % 5 == 0 then
    score = score - 3
  else
    score = score + 1
  end
end
print(score)
