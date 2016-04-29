local unpack = require'rethinkdb.unpack'

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
    -- {
    --   "success": <bool>,
    --   "authentication": "r=<nonce><server_nonce>,s=<salt>,i=<iteration>"
    -- }
    -- the authentication property will need to be retained
    local authentication = {}

    while 1 do
      local buf, err = raw_socket.recv()
      if not buf then
        return buffer, err
      end
      buffer = buffer .. buf
      local i = buf:find('\0')
      if i then
        local status_str = buffer:sub(1, i - 1)
        buffer = buffer:sub(i + 1)
        print(status_str)
        local response = pcall(_r.decode, status_str)
        if response == nil then
          return buffer, status_str
        end
        if not response.success then
          if 10 <= response.error_code and response.error_code <= 20 then
            return buffer, response.error  -- TODO authentication error
          end
          return buffer, response.error
        end
        response.authentication = response.authentication .. ','
        for k, v in response.authentication:gmatch('([rsi])=(.-),') do
          authentication[k] = v
        end
        if authentication.r:sub(1, #nonce) ~= nonce then
          return buffer, 'Invalid nonce'
        end
        break
      end
    end

    -- send the third client message
    -- {
    --   "authentication": "c=biws,r=<nonce><server_nonce>,p=<proof>"
    -- }
    raw_socket.send(_r.encode({
    }), '\0')

    -- wait for the third server challenge
    -- this is always a json document
    -- {
    --   "success": <bool>,
    --   "authentication": "v=<server_signature>"
    -- }

    while 1 do
      local buf, err = raw_socket.recv()
      if not buf then
        return buffer, err
      end
      buffer = buffer .. buf
      local i = buf:find('\0')
      if i then
        local status_str = buffer:sub(1, i - 1)
        buffer = buffer:sub(i + 1)
        print(status_str)
        local response = pcall(_r.decode, status_str)
        if response == nil then
          return buffer, status_str
        end
        if not response.success then
          if 10 <= response.error_code and response.error_code <= 20 then
            return buffer, response.error  -- TODO authentication error
          end
          return buffer, response.error
        end

        -- TODO verify server signature here

        return buffer
      end
    end
  end
end

return m
