--- Helper for bitwise operations.
-- slow implementations for Lua 5.1 without luabitops
-- only includes functions used by lua-reql
-- @module rethinkdb.internal.bits
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local modf = _G.math.modf

local m = {}

--- bitwise or of two values
-- @int l integer bitfield 1
-- @int r integer bitfield 2
-- @treturn int
function m.bor(l, r)
  local i, n, a, b = 0, 0
  while l > 0 or r > 0 do
    l, a = modf(l / 2)
    r, b = modf(r / 2)
    if a == 0.5 or b == 0.5 then n = n + 2 ^ i end
    i = i + 1
  end
  return n
end

--- bitwise exclusive or of two values
-- @int l integer bitfield 1
-- @int r integer bitfield 2
-- @treturn int
function m.bxor(l, r)
  local i, n, a, b = 0, 0
  while l > 0 or r > 0 do
    l, a = modf(l / 2)
    r, b = modf(r / 2)
    if a ~= b then n = n + 2 ^ i end
    i = i + 1
  end
  return n
end

return m
