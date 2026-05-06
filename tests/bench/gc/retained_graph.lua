-- name: gc/retained_graph
-- category: gc
-- expect: pass

local nodes = {}
for i = 1, 300 do
  nodes[i] = { value = i, next = nodes[i - 1] }
end

local sum = 0
local node = nodes[#nodes]
while node do
  sum = sum + node.value
  node = node.next
end
print(sum)
