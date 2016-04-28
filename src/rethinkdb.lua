local int_to_bytes = require'rethinkdb.int_to_bytes'

local _r = {
  lib_ssl = require('ssl')
}

-- r is both the main export table for the module
-- and a function that wraps a native Lua value in a ReQL datum
local r = {
  is_instance = require'rethinkdb.is_instance'
}

local meta_table, __call = require'rethinkdb.ast'.init(_r)
local __index = meta_table.__index

setmetatable(r, {__call = __call, __index = __index})
setmetatable(_r, {__call = __call, __index = __index})

r.Connection = require'rethinkdb.connection'.init(_r)
r.pool = require'rethinkdb.pool'.init(_r)

function r.connect(host_or_callback, callback)
  local host = {}
  if type(host_or_callback) == 'function' then
    callback = host_or_callback
  elseif type(host_or_callback) == 'string' then
    host = {host = host_or_callback}
  elseif host_or_callback then
    host = host_or_callback
  end
  return r.Connection(host).connect(callback)
end

function _r.logger(err)
  if r.logger then
    r.logger(err)
  elseif type(err) == 'string' then
    error(err)
  elseif type(err) == 'table' and err.msg then
    error(err.msg)
  else
    error('Unknown error type from driver')
  end
end

function _r.unb64(data)
  if r.unb64 then
    return r.unb64(data)
  elseif not _r.lib_mime then
    _r.lib_mime = require('mime')
  end
  r.unb64 = _r.lib_mime.unb64
  return r.unb64(data)
end

function _r.b64(data)
  if r.b64 then
    return r.b64(data)
  elseif not _r.lib_mime then
    _r.lib_mime = require('mime')
  end
  r.b64 = _r.lib_mime.b64
  return r.b64(data)
end

function _r.encode(data)
  if r.encode then
    return r.encode(data)
  elseif r.json_parser then
    r.encode = r.json_parser.encode
    return r.encode(data)
  elseif not _r.lib_json then
    if ngx == nil then
      _r.lib_json = require('json')
    else
      _r.lib_json = require('cjson')
    end
  end
  r.json_parser = _r.lib_json
  r.encode = _r.lib_json.encode
  return r.encode(data)
end

function _r.decode(buffer)
  if r.decode then
    return r.decode(buffer)
  elseif r.json_parser then
    r.decode = r.json_parser.decode
    return r.decode(buffer)
  elseif not _r.lib_json then
    if ngx == nil then
      _r.lib_json = require('json')
    else
      _r.lib_json = require('cjson')
    end
  end
  r.json_parser = _r.lib_json
  r.decode = _r.lib_json.decode
  return r.decode(buffer)
end

function _r.socket()
  if r.socket then
    return r.socket()
  elseif not _r.lib_socket then
    if ngx == nil then
      _r.lib_socket = require('socket')
    else
      _r.lib_socket = ngx.socket
    end
  end
  r.socket = _r.lib_socket.tcp
  return r.socket()
end

function _r.select(...)
  if r.select then
    return r.select(...)
  elseif not _r.lib_socket then
    if ngx == nil then
      _r.lib_socket = require('socket')
    else
      _r.lib_socket = ngx.socket
    end
  end
  r.select = _r.lib_socket.select
  return r.select(...)
end

function r.proto_V0_3(raw_socket, auth_key)
  -- Initialize connection with magic number to validate version
  raw_socket.send(
    '\62\232\117\95',
    int_to_bytes(#(auth_key), 4),
    auth_key,
    '\199\112\105\126'
  )

  local buffer = ''

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  while 1 do
    local buf, err = raw_socket.recv()
    if not buf then
      return nil, err
    end
    buffer = buffer .. buf
    local i, _ = buf:find('\0')
    if i then
      if buffer == 'SUCCESS' then
        -- We're good, finish setting up the connection
        return raw_socket, nil
      end
      return nil, buffer
    end
  end
end

function r.proto_V0_4(raw_socket, auth_key)
  -- Initialize connection with magic number to validate version
  raw_socket.send(
    '\32\45\12\64',
    int_to_bytes(#(auth_key), 4),
    auth_key,
    '\199\112\105\126'
  )

  local buffer = ''

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  while 1 do
    local buf, err = raw_socket.recv()
    if not buf then
      return nil, err
    end
    buffer = buffer .. buf
    local i, _ = buf:find('\0')
    if i then
      if buffer == 'SUCCESS' then
        -- We're good, finish setting up the connection
        return raw_socket, nil
      end
      return nil, buffer
    end
  end
end

r.proto_V1_0 = require'rethinkdb.current_protocol'.init(_r)

-- Export all names defined on r
return r
