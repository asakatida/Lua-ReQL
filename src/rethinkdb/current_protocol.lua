local bit = require('bit')
local bytes_to_int = require'rethinkdb.bytes_to_int'
local crypto = require('crypto')
local int_to_bytes = require'rethinkdb.int_to_bytes'

local rand_bytes = crypto.rand.bytes
local evp = crypto.evp
local hmac = crypto.hmac

local function __compare_digest(a, b)
  local left, result
  local right = b

  if #a == #b then
    left = a
    result = 0
  end
  if #a ~= #b then
    left = b
    result = 1
  end

  for i=1, #left do
    result = bit.bor(result, bit.bxor(left[i], right[i]))
  end

  return bit.tobit(result) ~= bit.tobit(0)
end

local pbkdf2_cache = {}

local function __pbkdf2_hmac(hash_name, password, salt, iterations)
  local cache_string = password .. ',' .. salt .. ',' .. iterations

  if pbkdf2_cache[cache_string] then
    return pbkdf2_cache[cache_string]
  end

  local function digest(msg)
    local mac = hmac.new(hash_name, password)
    local mac_copy = mac:clone()
    mac_copy:update(msg)
    return mac_copy:digest(nil, true)
  end

  local t = digest(salt .. '\0\0\0\1')
  local u = bytes_to_int(t)
  for _=1, iterations do
    t = digest(t)
    u = bit.bxor(u, bytes_to_int(t))
  end

  u = int_to_bytes(u, 8)
  pbkdf2_cache[cache_string] = u
  return u
end

local m = {}

function m.init(_r)
  return function(raw_socket, auth_key, user)
    local nonce = _r.b64(rand_bytes(18))

    local client_first_message_bare = 'n=' .. user .. ',r=' .. nonce

    raw_socket.send(
      '\32\45\12\64{"protocol_version":0,',
      '"authentication_method":"SCRAM-SHA-256",',
      '"authentication":"n,,', client_first_message_bare, '"}\0'
    )

    local buffer = ''

    local function get_message()
      local i = nil
      while not i do
        local buf, err = raw_socket.recv()
        if not buf then
          return nil, err
        end
        buffer = buffer .. buf
        i = (string.find(buffer, '\0'))
      end

      local message = string.sub(buffer, 1, i - 1)
      buffer = string.sub(buffer, i + 1)
      local success, response, err = pcall(_r.decode, message)

      if not success or type(response) ~= 'table' then
        return nil, err
      end

      return response
    end

    -- Now we have to wait for a response from the server
    -- acknowledging the connection
    -- this will be a null terminated json document on success
    -- or a null terminated error string on failure
    local response, err = get_message()

    if not response then
      return nil, err
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
    local server_first_message

    response, err = get_message()

    if not response then
      return nil, err
    end

    if not response.success then
      if 10 <= response.error_code and response.error_code <= 20 then
        return nil, response.error  -- TODO authentication error
      end
      return nil, response.error
    end
    server_first_message = response.authentication
    local response_authentication = server_first_message .. ','
    for k, v in string.gmatch(response_authentication, '([rsi])=(.-),') do
      authentication[k] = v
    end
    if string.sub(authentication.r, 1, #nonce) ~= nonce then
      return nil, 'Invalid nonce'
    end

    local client_final_message_without_proof = 'c=biws,r=' .. authentication.r

    local salt = _r.unb64(authentication.s)

    -- SaltedPassword := Hi(Normalize(password), salt, i)
    local salted_password = __pbkdf2_hmac('sha256', auth_key, salt, authentication.i)

    -- ClientKey := HMAC(SaltedPassword, "Client Key")
    local client_key = hmac.digest('sha256', salted_password .. 'Client Key', true)

    -- StoredKey := H(ClientKey)
    local stored_key = evp.digest('sha256', client_key, true)

    -- AuthMessage := client-first-message-bare + "," +
    --                server-first-message + "," +
    --                client-final-message-without-proof
    local auth_message = table.concat({
        client_first_message_bare,
        server_first_message,
        client_final_message_without_proof}, ',')

    -- ClientSignature := HMAC(StoredKey, AuthMessage)
    local client_signature = hmac.digest('sha256', stored_key .. auth_message, true)

    local client_proof = bit.bxor(bytes_to_int(client_key), bytes_to_int(client_signature))

    -- ServerKey := HMAC(SaltedPassword, "Server Key")
    local server_key = hmac.digest('sha256', salted_password .. 'Server Key', true)

    -- ServerSignature := HMAC(ServerKey, AuthMessage)
    local server_signature = hmac.digest('sha256', server_key .. auth_message, true)

    -- send the third client message
    -- {
    --   "authentication": "c=biws,r=<nonce><server_nonce>,p=<proof>"
    -- }
    raw_socket.send(_r.encode({
      authentication =
      client_final_message_without_proof ..
      ',p=' .. _r.b64(client_proof)
    }), '\0')

    -- wait for the third server challenge
    -- this is always a json document
    -- {
    --   "success": <bool>,
    --   "authentication": "v=<server_signature>"
    -- }
    response, err = get_message()

    if not response then
      return nil, err
    end

    if not response.success then
      if 10 <= response.error_code and response.error_code <= 20 then
        return nil, response.error  -- TODO authentication error
      end
      return nil, response.error
    end

    if not __compare_digest(response.v, server_signature) then
      return nil, response
    end

    return buffer
  end
end

return m
