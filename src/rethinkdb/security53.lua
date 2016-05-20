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
    result = result | (left[i] ~ right[i])
  end

  return result ~= 0
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
    u = u ~ bytes_to_int(t)
  end

  u = int_to_bytes(u, 8)
  pbkdf2_cache[cache_string] = u
  return u
end

local function __bxor(a, b)
  return a ~ b
end

return __bxor, __compare_digest, __pbkdf2_hmac
