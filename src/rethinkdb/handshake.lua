--- Interface to handshake with server.
-- @module rethinkdb.handshake
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local function new(auth_key, proto_version, user)
  local function handshake(socket_inst)
    local status, err = proto_version(socket_inst, auth_key, user)

    if status then
      return socket_inst
    end

    return nil, err
  end

  return handshake
end

return new
