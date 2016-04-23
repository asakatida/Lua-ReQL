local errors = require'rethinkdb.errors'
local int_to_bytes = require'rethinkdb.int_to_bytes'

-- r is both the main export table for the module
-- and a function that wraps a native Lua value in a ReQL datum
local r = {
  is_instance = require'rethinkdb.is_instance'
}
local _r = {}

_r.lib_ssl = require('ssl')

local ast = require'rethinkdb.ast'.init(r, _r)
local expr = require'rethinkdb.expr'.init(r, _r)

r.Connection = require'rethinkdb.connection'.init(r, _r)
r.pool = require'rethinkdb.pool'.init(r, _r)

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
  return _r.lib_mime.unb64(data)
end

function _r.b64(data)
  if r.b64 then
    return r.b64(data)
  elseif not _r.lib_mime then
    _r.lib_mime = require('mime')
  end
  r.b64 = _r.lib_mime.b64
  return _r.lib_mime.b64(data)
end

function _r.encode(data)
  if r.encode then
    return r.encode(data)
  elseif r.json_parser then
    r.encode = r.json_parser.encode
    return r.json_parser.encode(data)
  elseif not _r.lib_json then
    if ngx == nil then
      _r.lib_json = require('json')
    else
      _r.lib_json = require('cjson')
    end
  end
  r.encode = _r.lib_json.encode
  r.json_parser = _r.lib_json
  return _r.lib_json.encode(data)
end

function _r.decode(buffer)
  if r.decode then
    return r.decode(buffer)
  elseif r.json_parser then
    r.decode = r.json_parser.decode
    return r.json_parser.decode(buffer)
  elseif not _r.lib_json then
    if ngx == nil then
      _r.lib_json = require('json')
    else
      _r.lib_json = require('cjson')
    end
  end
  r.json_parser = _r.lib_json
  r.decode = _r.lib_json.decode
  return _r.lib_json.decode(buffer)
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

setmetatable(r, {
  __call = function(cls, val, nesting_depth)
    if nesting_depth == nil then
      nesting_depth = 20
    end
    if type(nesting_depth) ~= 'number' then
      return _r.logger('Second argument to `r(val, nesting_depth)` must be a number.')
    end
    if nesting_depth <= 0 then
      return _r.logger('Nesting depth limit exceeded')
    end
    if r.is_instance(val, 'ReQLOp') and type(val.build) == 'function' then
      return val
    end
    if type(val) == 'function' then
      return ast.FUNC({}, val)
    end
    if type(val) == 'table' then
      local array = true
      for k, v in pairs(val) do
        if type(k) ~= 'number' then array = false end
        val[k] = r(v, nesting_depth - 1)
      end
      if array then
        return ast.MAKE_ARRAY({}, unpack(val))
      end
      return ast.MAKE_OBJ(val)
    end
    if type(val) == 'userdata' then
      val = pcall(tostring, val)
      _r.logger('Found userdata inserting "' .. val .. '" into query')
      return ast.DATUMTERM(val)
    end
    if type(val) == 'thread' then
      val = pcall(tostring, val)
      _r.logger('Cannot insert thread object into query ' .. val)
      return nil
    end
    return ast.DATUMTERM(val)
  end
})

function r.proto_V0_3(raw_socket, auth_key)
  -- Initialize connection with magic number to validate version
  raw_socket:send(
    '\62\232\117\95' ..
    int_to_bytes(#(auth_key), 4) ..
    auth_key ..
    '\199\112\105\126'
  )

  local buf, err, partial
  local buffer = ''

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  while 1 do
    buf, err, partial = raw_socket:receive(8)
    buf = buf or partial
    if not buf then
      return nil, buffer, err
    end
    buffer = buffer .. buf
    i, j = buf:find('\0')
    if i then
      local status_str = buffer:sub(1, i - 1)
      buffer = buffer:sub(i + 1)
      if status_str == 'SUCCESS' then
        -- We're good, finish setting up the connection
        return raw_socket, buffer, err
      end
      return nil, buffer, err
    end
  end
end

function r.proto_V0_4(raw_socket, auth_key)
  -- Initialize connection with magic number to validate version
  raw_socket:send(
    '\32\45\12\64' ..
    int_to_bytes(#(auth_key), 4) ..
    auth_key ..
    '\199\112\105\126'
  )

  local buf, err, partial
  local buffer = ''

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  while 1 do
    buf, err, partial = raw_socket:receive(8)
    buf = buf or partial
    if not buf then
      return nil, buffer, err
    end
    buffer = buffer .. buf
    i, j = buf:find('\0')
    if i then
      local status_str = buffer:sub(1, i - 1)
      buffer = buffer:sub(i + 1)
      if status_str == 'SUCCESS' then
        -- We're good, finish setting up the connection
        return raw_socket, buffer, err
      end
      return nil, buffer, err
    end
  end
end

function r.proto_V1_0(raw_socket, auth_key, user)
  -- Initialize connection
  local nonce = {}
  for i=1,18 do
    nonce[i] = math.random(1, 0xFF)  -- TODO
  end
  raw_socket:send(
    '\32\45\12\64' ..
    '{"protocol_version":0,' ..
    '"authentication_method":"SCRAM-SHA-256",'  ..
    '"authentication":' ..
    '"n,,n=' .. conn.user ..
    ',r=' .. _r.b64(string.char(unpack(nonce))) ..
    '"}\0'
  )

  local buf, err, partial
  local buffer = ''

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  while 1 do
    buf, err, partial = raw_socket:receive()
    buf = buf or partial
    if not buf then
      return nil, buffer, err
    end
    buffer = buffer .. buf
  end
end

-- Export all names defined on r
return r
