--- Helper for converting an int to a string of bytes.
-- @module rethinkdb.int_to_bytes

local unpack = require'rethinkdb.unpack'

return function(num, bytes)
  local res = {}
  num = math.fmod(num, 2 ^ (8 * bytes))
  for k = bytes, 1, -1 do
    local den = 2 ^ (8 * (k - 1))
    res[k] = math.floor(num / den)
    num = math.fmod(num, den)
  end
  return string.char(unpack(res))
end
