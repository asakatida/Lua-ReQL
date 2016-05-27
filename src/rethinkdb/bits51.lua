--- Helper for bitwise operations.
-- slow implementations for Lua 5.1 without luabitops
-- only includes functions used by lua-reql
-- @module rethinkdb.bits
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local function pack_bits_impl(n, i, a, ...)
  if a then
    n = n + i
  elseif a == nil then
    return n
  end
  return pack_bits_impl(n, i * 2, ...)
end

local function pack_bits(...)
  return pack_bits_impl(0, 1, ...)
end

local function unpack_bits_impl(i, a, ...)
  if a == 0 then
    return ...
  elseif a < i then
    return unpack_bits_impl(i / 2, a - i, true, ...)
  end
  return unpack_bits_impl(i / 2, a, false, ...)
end

local function unpack_bits(a)
  local i = 1
  while a < i do
    i = i * 2
  end
  return unpack_bits_impl(i / 2, a)
end

local function bor_impl__(a, b, i, ...)
  local a_i = a[i]
  local b_i = b[i]

  if a_i == nil and b_i == nil then
    return ...
  end

  return bor_impl__(a, b, i + 1, ..., a_i or b_i)
end

local function bor_impl(...)
  local a = {...}

  local function bor_impl_(...)
    return bor_impl__(a, {...}, 1)
  end

  return bor_impl_
end

local function bxor_impl__(a, b, i, ...)
  local a_i = a[i]
  local b_i = b[i]

  if a_i == nil and b_i == nil then
    return ...
  end

  return bxor_impl__(a, b, i + 1, ..., (a_i and not b_i) or (b_i and not a_i))
end

local function bxor_impl(...)
  local a = {...}

  local function bxor_impl_(...)
    return bxor_impl__(a, {...}, 1)
  end

  return bxor_impl_
end

local m = {}

--- bitwise or of two values
-- @int a integer bitfield 1
-- @int b integer bitfield 2
-- @treturn int
function m.bor(a, b)
  return pack_bits(bor_impl(unpack_bits(a))(unpack_bits(b)))
end

--- bitwise exclusive or of two values
-- @int a integer bitfield 1
-- @int b integer bitfield 2
-- @treturn int
function m.bxor(a, b)
  return pack_bits(bxor_impl(unpack_bits(a))(unpack_bits(b)))
end

--- normalize integer to bitfield
-- @int a integer
-- @treturn int
function m.tobit(a)
  return m.bor(a, 0)
end

return m
