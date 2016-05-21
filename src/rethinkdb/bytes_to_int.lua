--- Helper for converting a string of bytes to an int.
-- @module rethinkdb.bytes_to_int

local function bytes_to_int(str)
  local t = {string.byte(str, 1, -1)}
  local n = 0
  for k=1, #t do
    n = n + t[k] * 2 ^ ((k - 1) * 8)
  end
  return n
end

return bytes_to_int
