--- Helpers to allow overriding driver internals.
-- @module rethinkdb.utilities
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local utilities = {}

--- convert ASCII base64 to 8bit
function utilities.unb64(r, base64)
  if r.unb64 then
    return r.unb64(base64)
  end
  local lib_mime = require('mime')
  r.unb64 = lib_mime.unb64
  if not r.b64 then
    r.b64 = lib_mime.b64
  end
  return r.unb64(base64)
end

--- convert 8bit to ASCII base64
function utilities.b64(r, bytes)
  if r.b64 then
    return r.unb64(bytes)
  end
  local lib_mime = require('mime')
  r.b64 = lib_mime.b64
  if not r.unb64 then
    r.unb64 = lib_mime.unb64
  end
  return r.b64(bytes)
end

--- convert Lua to JSON
function utilities.encode(r, obj)
  if r.encode then
    return r.encode(obj)
  elseif r.json_parser then
    r.encode = r.json_parser.encode
    return r.encode(obj)
  end
  if ngx == nil then  --luacheck: globals ngx
    r.json_parser = require('json')
  else
    r.json_parser = require('cjson')
  end
  r.encode = r.json_parser.encode
  return r.encode(obj)
end

--- convert JSON to Lua
function utilities.decode(r, json)
  if r.decode then
    return r.decode(json)
  elseif r.json_parser then
    r.decode = r.json_parser.decode
    return r.decode(json)
  end
  if ngx == nil then  --luacheck: globals ngx
    r.json_parser = require('json')
  else
    r.json_parser = require('cjson')
  end
  r.decode = r.json_parser.decode
  return r.decode(json)
end

--- create new tcp socket
function utilities.socket(r)
  if r.socket then
    return r.socket()
  end
  local lib_socket
  if ngx == nil then  --luacheck: globals ngx
    lib_socket = require('socket')
  else
    lib_socket = ngx.socket  --luacheck: globals ngx
  end
  r.socket = lib_socket.tcp
  if not r.select then
    r.select = lib_socket.select
  end
  return r.socket()
end

--- block waiting for socket status
function utilities._select(r, recvt, sendt, timeout)
  if r.select then
    return r.select(recvt, sendt, timeout)
  end
  local lib_socket
  if ngx == nil then  --luacheck: globals ngx
    lib_socket = require('socket')
  else
    lib_socket = ngx.socket  --luacheck: globals ngx
  end
  r.select = lib_socket.select
  if not r.socket then
    r.socket = lib_socket.tcp
  end
  return r.select(recvt, sendt, timeout)
end

return utilities
