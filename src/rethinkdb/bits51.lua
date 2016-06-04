--- Helper for bitwise operations.
-- slow implementations for Lua 5.1 without luabitops
-- only includes functions used by lua-reql
-- @module rethinkdb.bits
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local function pack_bits(a)
  local n = 0
  for i=1, #a do
    if a[i] then
      n = n + 2 ^ i
    end
  end
  return n
end

local function unpack_bits(a)
  local n = {}
  while a > 0 do
    local i
    a, i = math.modf(a / 2)
    table.insert(n, i == 0.5)
  end
  local l = #n
  for i=1, math.floor(l / 2) do
    l = l - 1
    n[i], n[l] = n[l], n[i]
  end
  return n
end

local function bor_impl(a, b)
  local n = {}
  for i=1, math.max(#a, #b) do
    n[i] = a[i] or b[i]
  end
  return n
end

local function bxor_impl(a, b)
  local n = {}
  for i=1, math.max(#a, #b) do
    if a[i] then
      n[i] = not b[i]
    else
      n[i] = b[i]
    end
  end
  return n
end

local m = {}

--- bitwise or of two values
-- @int a integer bitfield 1
-- @int b integer bitfield 2
-- @treturn int
function m.bor(a, b)
  return pack_bits(bor_impl(unpack_bits(a), unpack_bits(b)))
end

--- bitwise exclusive or of two values
-- @int a integer bitfield 1
-- @int b integer bitfield 2
-- @treturn int
function m.bxor(a, b)
  return pack_bits(bxor_impl(unpack_bits(a), unpack_bits(b)))
end

--- normalize integer to bitfield
-- @int a integer
-- @treturn int
function m.tobit(a)
  return m.bor(a, 0)
end

return m
