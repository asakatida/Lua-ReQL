local unpack = require 'rethinkdb.unpack'

local m = {}

function m.init(_r)
  return function(raw_socket, auth_key, user)
    -- Initialize connection
    local nonce = {}
    for i=1,18 do
      nonce[i] = math.random(1, 0xFF)  -- TODO
    end
    raw_socket.send(
      '\32\45\12\64{"protocol_version":0,',
      '"authentication_method":"SCRAM-SHA-256",',
      '"authentication":"n,,n=', user,
      ',r=', _r.b64(string.char(unpack(nonce))), '"}\0'
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
      local i, j = buf:find('\0')
      if i then
        local status_str = buffer:sub(1, i - 1)
        buffer = buffer:sub(i + 1)
        print(status_str)
        return nil, err
      end
    end
  end
end

return m
