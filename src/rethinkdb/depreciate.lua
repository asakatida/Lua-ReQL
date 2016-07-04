--- Interface
-- @module rethinkdb.reql
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local int_to_bytes = require'rethinkdb.internal.int_to_bytes'

local function proto_V0_x(raw_socket, auth_key, magic)
  -- Initialize connection with magic number to validate version
  local size, send_err = raw_socket.send(
    magic,
    int_to_bytes(#auth_key, 4),
    auth_key,
    '\199\112\105\126'
  )
  if not size then
    return nil, send_err
  end

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  local message, err = raw_socket.recv(8)
  if err then
    return nil, err
  end
  if message == 'SUCCESS\0' then
    -- We're good, finish setting up the connection
    return true
  end
  return nil, message .. ((raw_socket.recv'*a') or '')
end

local m = {}

function m.init(r)
  function r.proto_V0_3(raw_socket, auth_key)
    return proto_V0_x(raw_socket, auth_key, '\62\232\117\95')
  end

  function r.proto_V0_4(raw_socket, auth_key)
    return proto_V0_x(raw_socket, auth_key, '\32\45\12\64')
  end
end

return m
