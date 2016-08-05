--- Helper for converting a string of bytes to an int.
-- @module rethinkdb.internal.bytes_to_int
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

if not string.unpack then
  local function big_to_int(str)
    local n = 0
    for k=1, string.len(str) do
      n = n + string.byte(str, k) * 2 ^ ((k - 1) * 8)
    end
    return n
  end

  local function little_to_int(str)
    local n = 0
    local bytes = string.len(str)
    for k=1, bytes do
      n = n + string.byte(str, k) * 2 ^ ((bytes - k) * 8)
    end
    return n
  end

  return big_to_int, little_to_int
end

local function big_to_int(str)
  return (string.unpack('!1<I' .. string.len(str), str))
end

local function little_to_int(str)
  return (string.unpack('!1>I' .. string.len(str), str))
end

return big_to_int, little_to_int
