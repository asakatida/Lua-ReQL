--- Main interface combining public modules in an export table.
-- @module rethinkdb
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016
-- @alias r

local ast = require'rethinkdb.ast'
local connection = require'rethinkdb.connection'
local current_protocol = require'rethinkdb.current_protocol'
local int_to_bytes = require'rethinkdb.int_to_bytes'
local type_ = require'rethinkdb.type'

local v = require('rethinkdb.semver')

local function proto_V0_x(raw_socket, auth_key, magic)
  -- Initialize connection with magic number to validate version
  raw_socket.send(
    magic,
    int_to_bytes(#auth_key, 4),
    auth_key,
    '\199\112\105\126'
  )

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  local message, buffer = raw_socket.get_message('')

  if message == 'SUCCESS' then
    -- We're good, finish setting up the connection
    return buffer
  end
  if message then
    return nil, message
  end
  return nil, buffer
end

local function proto_V0_3(_, raw_socket, auth_key)
  return proto_V0_x(raw_socket, auth_key, '\62\232\117\95')
end

local function proto_V0_4(_, raw_socket, auth_key)
  return proto_V0_x(raw_socket, auth_key, '\32\45\12\64')
end

-- r is both the main export table for the module
-- and a function that wraps a native Lua value in a ReQL datum
local r = ast

r.Connection = connection
r.type = type_
r.version = v'1.0.0'

function r.connect(host_or_callback, callback)
  local host = {}
  if type(host_or_callback) == 'function' then
    callback = host_or_callback
  elseif type(host_or_callback) == 'string' then
    host = {host = host_or_callback}
  elseif host_or_callback then
    host = host_or_callback
  end
  if host.r == nil then host.r = r end
  return r.Connection(host).connect(callback)
end

r.proto_V0_3 = proto_V0_3
r.proto_V0_4 = proto_V0_4
r.proto_V1_0 = current_protocol

-- Export all names defined on r
return r
