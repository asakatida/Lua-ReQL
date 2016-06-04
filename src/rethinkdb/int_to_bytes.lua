--- Helper for converting an int to a string of bytes.
-- @module rethinkdb.int_to_bytes
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

if string.pack then
  local function int_to_bytes(num, bytes)
    return string.pack('!1>I' .. bytes, num)
  end

  return int_to_bytes
end

local unpack = _G.unpack or table.unpack

local function int_to_bytes(num, bytes)
  local res = {}
  num = math.fmod(num, 2 ^ (8 * bytes))
  for k = bytes, 1, -1 do
    local den = 2 ^ (8 * (k - 1))
    res[k] = math.floor(num / den)
    num = math.fmod(num, den)
  end
  return string.char(unpack(res))
end

return int_to_bytes
