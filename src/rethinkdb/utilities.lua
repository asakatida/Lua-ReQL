--- Helpers to allow overriding driver internals.
-- @module rethinkdb.utilities

local function logger(r, err)
  if r.logger then
    return r.logger(err)
  elseif type(err) == 'string' then
    error(err)
  else
    error('Unknown error type from driver')
  end
end

local function unb64(r, ...)
  if r.unb64 then
    return r.unb64(...)
  end
  local lib_mime = require('mime')
  r.unb64 = lib_mime.unb64
  if not r.b64 then
    r.b64 = lib_mime.b64
  end
  return r.unb64(...)
end

local function b64(r, ...)
  if r.b64 then
    return r.unb64(...)
  end
  local lib_mime = require('mime')
  r.b64 = lib_mime.b64
  if not r.unb64 then
    r.unb64 = lib_mime.unb64
  end
  return r.b64(...)
end

local function encode(r, ...)
  if r.encode then
    return r.encode(...)
  elseif r.json_parser then
    r.encode = r.json_parser.encode
    return r.encode(...)
  end
  if ngx == nil then
    r.json_parser = require('json')
  else
    r.json_parser = require('cjson')
  end
  r.encode = r.json_parser.encode
  return r.encode(...)
end

local function decode(r, ...)
  if r.decode then
    return r.decode(...)
  elseif r.json_parser then
    r.decode = r.json_parser.decode
    return r.decode(...)
  end
  if ngx == nil then
    r.json_parser = require('json')
  else
    r.json_parser = require('cjson')
  end
  r.decode = r.json_parser.decode
  return r.decode(...)
end

local function socket(r, ...)
  if r.socket then
    return r.socket(...)
  end
  local lib_socket
  if ngx == nil then
    lib_socket = require('socket')
  else
    lib_socket = ngx.socket
  end
  r.socket = lib_socket.tcp
  if not r.select then
    r.select = lib_socket.select
  end
  return r.socket(...)
end

local function select(r, ...)
  if r.select then
    return r.select(...)
  end
  local lib_socket
  if ngx == nil then
    lib_socket = require('socket')
  else
    lib_socket = ngx.socket
  end
  r.select = lib_socket.select
  if not r.socket then
    r.socket = lib_socket.tcp
  end
  return r.select(...)
end

local _r = {
  logger = logger,
  unb64 = unb64,
  b64 = b64,
  encode = encode,
  decode = decode,
  socket = socket,
  select = select,
}

return _r
