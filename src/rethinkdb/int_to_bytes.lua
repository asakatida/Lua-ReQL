return function(num, bytes)
  local res = {}
  local mul = 0
  for k = bytes, 1, -1 do
    local den = 2 ^ (8 * (k - 1))
    res[k] = math.floor(num / den)
    num = math.fmod(num, den)
  end
  return string.char(unpack(res))
end
