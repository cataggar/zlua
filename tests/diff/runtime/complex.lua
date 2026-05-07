-- evil55.lua
-- Run on CLua 5.5 and zlua. Any mismatch is deliciously suspicious.
-- I have not run this in this chat sandbox, so CLua gets the final say, as always. Rude but fair.

local tests = {}

local function test(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

local function expect(cond, msg)
  if not cond then
    error(msg or "assertion failed", 2)
  end
end

local function must_compile(src, env)
  local f, err = load(src, "=evil55_chunk", "t", env)
  if not f then
    error("expected compile success, got: " .. tostring(err), 2)
  end
  return f
end

local function must_not_compile(src)
  local f, err = load(src, "=should_not_compile", "t", {})
  if f then
    error("expected compile failure, but chunk compiled", 2)
  end
  expect(type(err) == "string" and #err > 0, "missing compiler error")
end

test("5.5 compile-time restrictions", function()
  must_not_compile("local<const> a = 1; a = 2")
  must_not_compile("local<const> a, b = 1, 2; b = 3")

  must_not_compile("for i = 1, 3 do i = i + 1 end")
  must_not_compile("for k, v in next, { x = 1 }, nil do k = 'nope' end")

  must_not_compile("return function(... args) args = {} end")

  must_not_compile("global none\nx = 1")
  must_not_compile("global<const> *\nmath = {}")
end)

test("global declarations runtime semantics", function()
  local env = {}
  local f = must_compile([[
    global X = 12
    X = X + 1
    return X, _ENV.X
  ]], env)

  local a, b = f()
  expect(a == 13 and b == 13 and env.X == 13, "global init/update mismatch")

  local already = { X = 1 }
  local f2 = must_compile([[
    global X = 99
    return X
  ]], already)

  local ok, msg = pcall(f2)
  expect(not ok and type(msg) == "string", "global init over existing value should error")

  local f3 = must_compile([[
    global Y
    Y = 22
    return Y
  ]], {})

  expect(f3() == 22, "declared global assignment failed")
end)

test("named vararg table mutates what ... expands", function()
  local function f(prefix, ... args)
    expect(prefix == "fixed", "fixed parameter mismatch")
    expect(args.n == 4, "vararg n should preserve nils")
    expect(args[1] == "a", "arg 1 mismatch")
    expect(args[2] == nil, "arg 2 should be nil")
    expect(args[3] == "c", "arg 3 mismatch")
    expect(args[4] == false, "arg 4 mismatch")

    args[2] = "patched-nil"
    args.n = 5
    args[5] = "tail"

    return table.pack(...)
  end

  local r = f("fixed", "a", nil, "c", false)

  expect(r.n == 5, "... did not respect mutated args.n")
  expect(r[1] == "a", "expanded arg 1 mismatch")
  expect(r[2] == "patched-nil", "... ignored mutation to named vararg table")
  expect(r[3] == "c", "expanded arg 3 mismatch")
  expect(r[4] == false, "expanded arg 4 mismatch")
  expect(r[5] == "tail", "... ignored extended named vararg table")
end)

test("named vararg table can be captured", function()
  local function f(... args)
    return function(i)
      return args[i], args.n
    end
  end

  local g = f("x", nil, "z")
  local v2, n2 = g(2)
  local v3, n3 = g(3)

  expect(v2 == nil and n2 == 3, "captured nil vararg mismatch")
  expect(v3 == "z" and n3 == 3, "captured vararg table mismatch")
end)

test("table.create behaves like an empty preallocated table", function()
  local t = table.create(16, 4)

  expect(type(t) == "table", "table.create did not return table")
  expect(next(t) == nil, "table.create table should start empty")
  expect(#t == 0, "empty preallocated sequence length should be zero")

  for i = 1, 16 do
    t[i] = i
  end

  t.a, t.b, t.c, t.d = 1, 2, 3, 4

  expect(#t == 16, "filled sequence length mismatch")
  expect(t[16] == 16 and t.d == 4, "table.create storage mismatch")

  t[8] = nil
  expect(rawget(t, 8) == nil and t[9] == 9, "array hole/rawget mismatch")
end)

test("utf8.offset returns start and end byte positions", function()
  local s = "aé𝄞z"

  expect(#s == 8, "test string byte length changed")

  local a1, a2 = utf8.offset(s, 1)
  local b1, b2 = utf8.offset(s, 2)
  local c1, c2 = utf8.offset(s, 3)
  local d1, d2 = utf8.offset(s, 0, 5)
  local e1, e2 = utf8.offset(s, -1)

  expect(a1 == 1 and a2 == 1, "ASCII offset mismatch")
  expect(b1 == 2 and b2 == 3, "2-byte UTF-8 offset mismatch")
  expect(c1 == 4 and c2 == 7, "4-byte UTF-8 offset mismatch")
  expect(d1 == 4 and d2 == 7, "n=0 containing-char offset mismatch")
  expect(e1 == 8 and e2 == 8, "negative offset from end mismatch")

  local z = utf8.offset(s, 99)
  expect(z == nil or z == false, "out-of-range utf8.offset should fail")
end)

test("nil error object is replaced", function()
  local ok, msg = pcall(error, nil)
  expect(ok == false, "error(nil) should fail")
  expect(msg ~= nil and type(msg) == "string", "nil error object was not replaced")

  local ok2, msg2 = pcall(function() end)
  expect(ok2 == true and msg2 == nil, "plain pcall success mismatch")

  local ok3, msg3 = pcall(error, false)
  expect(ok3 == false and msg3 == false, "false error object should stay false")
end)

test("__call chain limit", function()
  local leaf = function(...)
    return "ok", select("#", ...)
  end

  local x = leaf
  for _ = 1, 15 do
    x = setmetatable({}, { __call = x })
  end

  local ok, res, argc = pcall(x, "arg")
  expect(ok and res == "ok" and argc == 16, "15-object __call chain should work")

  local y = leaf
  for _ = 1, 16 do
    y = setmetatable({}, { __call = y })
  end

  local ok2 = pcall(y)
  expect(ok2 == false, "16-object __call chain should fail")
end)

test("table __gc order and resurrection", function()
  local order = {}
  local resurrected = nil

  local mt = {
    __gc = function(o)
      order[#order + 1] = o.id
      if o.id == 2 and resurrected == nil then
        resurrected = o
      end
    end
  }

  do
    local keep = {}
    for i = 1, 3 do
      keep[i] = setmetatable({ id = i }, mt)
    end
    keep = nil
  end

  collectgarbage("collect")

  expect(table.concat(order, ",") == "3,2,1", "table finalizer order mismatch")
  expect(resurrected and resurrected.id == 2, "resurrection failed")

  order = {}
  resurrected = nil
  collectgarbage("collect")

  expect(#order == 0, "resurrected object finalized twice without re-marking")
end)

test("ephemeron weak-key table removes key/value cycles", function()
  local w = setmetatable({}, { __mode = "k" })

  do
    local k = {}
    w[k] = { back = k }
  end

  for _ = 1, 4 do
    collectgarbage("collect")
  end

  expect(next(w) == nil, "ephemeron entry survived unexpectedly")
end)

test("number/table edge cases", function()
  local t = {}

  t[2.0] = "two"
  expect(t[2] == "two", "integral float key did not canonicalize to integer")

  local ok = pcall(function()
    t[0 / 0] = true
  end)

  expect(not ok, "NaN table key should error")
  expect(math.maxinteger + 1 == math.mininteger, "integer wrap mismatch")
  expect(-math.mininteger == math.mininteger, "mininteger negation wrap mismatch")
end)

test("to-be-closed order with nil error replacement", function()
  local log = {}

  local mt = {
    __close = function(self, err)
      log[#log + 1] = self.name .. ":" .. type(err)
    end
  }

  local function boom()
    local<close> a = setmetatable({ name = "a" }, mt)
    local<close> b = setmetatable({ name = "b" }, mt)
    error(nil)
  end

  local ok, msg = pcall(boom)

  expect(not ok and type(msg) == "string", "nil error object mismatch through pcall")
  expect(log[1] == "b:string" and log[2] == "a:string", "__close order/error mismatch")
end)

local failures = 0

for _, t in ipairs(tests) do
  local ok, err = pcall(t.fn)

  if ok then
    io.write("ok   ", t.name, "\n")
  else
    failures = failures + 1
    io.stderr:write("FAIL ", t.name, "\n")
    io.stderr:write(tostring(err), "\n")
  end
end

if failures ~= 0 then
  error(("evil55 found %d failure(s)"):format(failures), 0)
end

print(("all %d evil Lua 5.5 probes passed"):format(#tests))
