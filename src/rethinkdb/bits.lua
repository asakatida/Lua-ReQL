--- Helper for bitwise operations.
-- @module rethinkdb.bits
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local function prequire(mod_name, ...)
  if not mod_name then return end

  local success, bits = pcall(require, mod_name)

  if success then
    return true, bits
  end

  return prequire(...)
end

local success, bits = prequire('rethinkdb.bits53', 'bit32', 'bit')

if success then
  return bits
end

return require'rethinkdb.bits51'
