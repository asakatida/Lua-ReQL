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
    -- this will be a null terminated json document on success
    -- or a null terminated error string on failure
    while 1 do
      local buf, err = raw_socket.recv()
      if not buf then
        return nil, err
      end
      buffer = buffer .. buf
      local i, _ = buf:find('\0')
      if i then
        local status_str = buffer:sub(1, i - 1)
        buffer = buffer:sub(i + 1)
        print(status_str)
        local response = pcall(_r.decode, status_str)
        if response == nil then
          return nil, status_str
        end
        break
      end
    end

    -- when protocol versions are updated this is where we send the following
    -- for now it is sent above
    -- {
    --   "protocol_version": <number>,
    --   "authentication_method": <method>,
    --   "authentication": "n,,n=<user>,r=<nonce>"
    -- }

    -- wait for the second server challenge
    -- this is always a json document
    while 1 do
    end
  end
end

return m
