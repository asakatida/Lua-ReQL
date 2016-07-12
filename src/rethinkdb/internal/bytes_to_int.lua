--- Helper for converting a string of bytes to an int.
-- @module rethinkdb.internal.bytes_to_int
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

if string.unpack then
  local function bytes_to_int(str)
    return (string.unpack('!1<I' .. string.len(str), str))
  end

  return bytes_to_int
end

local function bytes_to_int(str)
  local t = {string.byte(str, 1, -1)}
  local n = 0
  for k=1, #t do
    n = n + t[k] * 2 ^ ((k - 1) * 8)
  end
  return n
end

return bytes_to_int
