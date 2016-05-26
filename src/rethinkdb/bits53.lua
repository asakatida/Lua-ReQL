--- Helper for bitwise operations.
-- valid where the vm supports bitops
-- only includes functions used by lua-reql
-- @module rethinkdb.bits
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local m = {}

--- bitwise or of two values
-- @int a integer bitfield 1
-- @int b integer bitfield 2
-- @treturn int
function m.bor(a, b)
  return a | b
end

--- bitwise exclusive or of two values
-- @int a integer bitfield 1
-- @int b integer bitfield 2
-- @treturn int
function m.bxor(a, b)
  return a ~ b
end

--- normalize integer to bitfield
-- @int a integer
-- @treturn int
function m.tobit(a)
  return a | 0
end

return m
