local int_to_bytes = require'rethinkdb.int_to_bytes'
local v = require('rethinkdb.semver')

-- r is both the main export table for the module
-- and a function that wraps a native Lua value in a ReQL datum
local r = require'rethinkdb.ast'

r.Connection = require'rethinkdb.connection'
r.pool = require'rethinkdb.pool'
r.type = require'rethinkdb.type'
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

function r.proto_V0_3(raw_socket, auth_key)
  -- Initialize connection with magic number to validate version
  raw_socket.send(
    '\62\232\117\95',
    int_to_bytes(#(auth_key), 4),
    auth_key,
    '\199\112\105\126'
  )

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  local message, buffer = raw_socket.get_message('')

  if message == 'SUCCESS' then
    -- We're good, finish setting up the connection
    return ''
  end
  return nil, message, buffer
end

function r.proto_V0_4(raw_socket, auth_key)
  -- Initialize connection with magic number to validate version
  raw_socket.send(
    '\32\45\12\64',
    int_to_bytes(#(auth_key), 4),
    auth_key,
    '\199\112\105\126'
  )

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  local message, buffer = raw_socket.get_message('')

  if message == 'SUCCESS' then
    -- We're good, finish setting up the connection
    return ''
  end
  return nil, message, buffer
end

r.proto_V1_0 = require'rethinkdb.current_protocol'

-- Export all names defined on r
return r
