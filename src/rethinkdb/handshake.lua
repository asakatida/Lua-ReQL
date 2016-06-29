--- Interface to handshake with server.
-- @module rethinkdb.handshake
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local function new(auth_key, proto_version, user)
  local function handshake(socket_inst)
    local fake_socket = {r = socket_inst.r, send = socket_inst.send}

    function fake_socket.get_success()
      local buffer, err = socket_inst.recv(8)
      if err then
        return nil, err
      end
      if buffer == 'SUCCESS\0' then
        return true
      end
      return nil, buffer .. ((socket_inst.recv'*a') or '')
    end

    local buffer = ''

    function fake_socket.decode_message()
      local i = nil
      while not i do
        local buf, err = socket_inst.recv(32)
        if err then
          return nil, err
        end
        buffer = buffer .. buf
        i = string.find(buffer, '\0')
      end

      local message = string.sub(buffer, 1, i - 1)
      buffer = string.sub(buffer, i + 1)

      local response = socket_inst.r.decode(message)

      if not response then
        return nil, message
      end

      return response, nil
    end

    local status, err = proto_version(fake_socket, auth_key, user)

    if status then
      return socket_inst
    end

    return nil, err
  end

  return handshake
end

return new
