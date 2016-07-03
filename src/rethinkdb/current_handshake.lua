--- Handler implementing latest RethinkDB handshake.
-- @module rethinkdb.current_handshake
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local crypto = require('crypto')

--- Helper for bitwise operations.
local function prequire(mod_name, ...)
  if not mod_name then return end

  local success, bits = pcall(require, mod_name)

  if success then
    return true, bits
  end

  return prequire(...)
end

local success, bits = prequire(
  'rethinkdb.bits53', 'bit32', 'bit', 'rethinkdb.bits51')

if success then
  if not bits.tobit then
    --- normalize integer to bitfield
    -- @int a integer
    -- @treturn int
    function bits.tobit(a)
      return bits.bor(a, 0)
    end
  end
end

local bor = bits.bor
local bxor = bits.bxor
local tobit = bits.tobit
local rand_bytes = crypto.rand.bytes
local hmac = crypto.hmac

local unpack = _G.unpack or table.unpack

local function bxor256(u, t)
  local res = {}
  for i=1, math.max(string.len(u), string.len(t)) do
    res[i] = bxor(string.byte(u, i) or 0, string.byte(t, i) or 0)
  end
  return string.char(unpack(res))
end

local function __compare_digest(a, b)
  local result

  if string.len(a) == string.len(b) then
    result = 0
  end
  if string.len(a) ~= string.len(b) then
    result = 1
  end

  for i=1, math.max(string.len(a), string.len(b)) do
    result = bor(result, bxor(string.byte(a, i) or 0, string.byte(b, i) or 0))
  end

  return tobit(result) ~= tobit(0)
end

local function __pbkdf2_hmac(hash_name, password, salt, iterations)
  local function digest(msg)
    local mac = hmac.new(hash_name, password)
    mac:update(msg)
    return mac:final(nil, true)
  end

  local t = digest(salt .. '\0\0\0\1')
  if iterations < 4096 then
    return t
  end
  local u = t
  for _=1, iterations do
    t = digest(t)
    u = bxor256(u, t)
  end

  return u
end

local function current_handshake(raw_socket, auth_key, user)
  local buffer = ''

  local r = raw_socket.r

  local function decode_message()
    local i = nil
    while not i do
      local buf, err = raw_socket.recv(32)
      if err then
        return nil, err
      end
      buffer = buffer .. buf
      i = string.find(buffer, '\0')
    end

    local message = string.sub(buffer, 1, i - 1)
    buffer = string.sub(buffer, i + 1)

    local response = r.decode(message)

    if not response then
      return nil, message
    end

    return response, nil
  end

  local nonce = r.b64(rand_bytes(18))

  local client_first_message_bare = 'n=' .. user .. ',r=' .. nonce

  local size, send_err = raw_socket.send(
    '\195\189\194\52', r.encode{
      protocol_version = 0,
      authentication_method = 'SCRAM-SHA-256',
      authentication = 'n,,' .. client_first_message_bare
    }, '\0'
  )
  if not size then
    return nil, send_err
  end
  if send_err and send_err ~= '' then
    size, send_err = raw_socket.send(send_err)
    if not size then
      return nil, send_err
    end
    if send_err and send_err ~= '' then
      return nil, 'Incomplete protocol sent'
    end
  end

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  -- this will be a null terminated json document on success
  -- or a null terminated error string on failure
  local response, err = decode_message()

  if not response then
    return nil, err
  end

  if not response.success then
    return nil, response
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

  response, err = decode_message()

  if not response then
    return nil, err
  end

  if not response.success then
    return nil, response
  end

  server_first_message = response.authentication
  local response_authentication = server_first_message .. ','
  for k, v in string.gmatch(response_authentication, '([rsi])=(.-),') do
    authentication[k] = v
  end

  if string.sub(authentication.r, 1, #nonce) ~= nonce then
    return nil, 'Invalid nonce'
  end

  authentication.i = tonumber(authentication.i)

  local client_final_message_without_proof = 'c=biws,r=' .. authentication.r

  local salt = r.unb64(authentication.s)

  -- SaltedPassword := Hi(Normalize(password), salt, i)
  local salted_password = __pbkdf2_hmac('sha256', auth_key, salt, authentication.i)

  -- ClientKey := HMAC(SaltedPassword, "Client Key")
  local client_key = hmac.digest('sha256', salted_password, 'Client Key', true)

  -- StoredKey := H(ClientKey)
  local stored_key = crypto.digest('sha256', client_key, true)

  -- AuthMessage := client-first-message-bare + "," +
  --                server-first-message + "," +
  --                client-final-message-without-proof
  local auth_message = table.concat({
      client_first_message_bare,
      server_first_message,
      client_final_message_without_proof}, ',')

  -- ClientSignature := HMAC(StoredKey, AuthMessage)
  local client_signature = hmac.digest('sha256', stored_key, auth_message, true)

  local client_proof = bxor256(client_key, client_signature)

  -- ServerKey := HMAC(SaltedPassword, "Server Key")
  local server_key = hmac.digest('sha256', salted_password, 'Server Key', true)

  -- ServerSignature := HMAC(ServerKey, AuthMessage)
  local server_signature = hmac.digest('sha256', server_key, auth_message, true)

  -- send the third client message
  -- {
  --   "authentication": "c=biws,r=<nonce><server_nonce>,p=<proof>"
  -- }
  size, send_err = raw_socket.send(r.encode{
    authentication =
    table.concat({client_final_message_without_proof, r.b64(client_proof)}, ',p=')
  }, '\0')
  if not size then
    return nil, send_err
  end
  if send_err and send_err ~= '' then
    size, send_err = raw_socket.send(send_err)
    if not size then
      return nil, send_err
    end
    if send_err and send_err ~= '' then
      return nil, 'Incomplete protocol sent'
    end
  end

  -- wait for the third server challenge
  -- this is always a json document
  -- {
  --   "success": <bool>,
  --   "authentication": "v=<server_signature>"
  -- }
  response, err = decode_message()

  if not response then
    return nil, err
  end

  if not response.success then
    return nil, response
  end

  if not __compare_digest(response.v, server_signature) then
    return nil, response
  end

  return true
end

return current_handshake
