
if not jit then  --luacheck: globals jit
  local success, __bxor, __compare_digest, __pbkdf2_hmac = pcall(
    require, 'rethinkdb.security53')
  if success then
    return __bxor, __compare_digest, __pbkdf2_hmac
  end
end

local success, bit = pcall(require, 'bit32')

if not success then
  bit = require('bit')
end

local bytes_to_int = require'rethinkdb.bytes_to_int'
local crypto = require('crypto')
local int_to_bytes = require'rethinkdb.int_to_bytes'

local hmac = crypto.hmac

local function __compare_digest(a, b)
  local left, result
  local right = b

  if #a == #b then
    left = a
    result = 0
  end
  if #a ~= #b then
    left = b
    result = 1
  end

  for i=1, #left do
    result = bit.bor(result, bit.bxor(left[i], right[i]))
  end

  return bit.tobit(result) ~= bit.tobit(0)
end

local pbkdf2_cache = {}

local function __pbkdf2_hmac(hash_name, password, salt, iterations)
  local cache_string = password .. ',' .. salt .. ',' .. iterations

  if pbkdf2_cache[cache_string] then
    return pbkdf2_cache[cache_string]
  end

  local function digest(msg)
    local mac = hmac.new(hash_name, password)
    local mac_copy = mac:clone()
    mac_copy:update(msg)
    return mac_copy:digest(nil, true)
  end

  local t = digest(salt .. '\0\0\0\1')
  local u = bytes_to_int(t)
  for _=1, iterations do
    t = digest(t)
    u = bit.bxor(u, bytes_to_int(t))
  end

  u = int_to_bytes(u, 8)
  pbkdf2_cache[cache_string] = u
  return u
end

return bit.bxor, __compare_digest, __pbkdf2_hmac
