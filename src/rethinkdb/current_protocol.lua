--- Handler implementing latest RethinkDB handshake.
-- @module rethinkdb.current_protocol

local utilities = require'rethinkdb.utilities'

local __bxor, __compare_digest, __pbkdf2_hmac = require'rethinkdb.security'
local bytes_to_int = require'rethinkdb.bytes_to_int'
local crypto = require('crypto')

local unb64 = utilities.unb64
local b64 = utilities.b64
local encode = utilities.encode
local decode = utilities.decode

local rand_bytes = crypto.rand.bytes
local evp = crypto.evp
local hmac = crypto.hmac

return function(r, raw_socket, auth_key, user)
  local nonce = b64(r, rand_bytes(18))

  local client_first_message_bare = 'n=' .. user .. ',r=' .. nonce

  raw_socket.send(
    '\195\189\194\52{"protocol_version":0,',
    '"authentication_method":"SCRAM-SHA-256",',
    '"authentication":"n,,', client_first_message_bare, '"}\0'
  )

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  -- this will be a null terminated json document on success
  -- or a null terminated error string on failure
  local message, buffer = raw_socket.get_message('')

  if not message then
    return nil, buffer
  end

  local success, response = pcall(decode, r, message)

  if not success then
    return nil, message
  end

  if response.success ~= true then
    return nil, message
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

  response, buffer = raw_socket.decode_message(buffer)

  if not response then
    return nil, buffer
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

  local salt = unb64(r, authentication.s)

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

  local client_proof = __bxor(bytes_to_int(client_key), bytes_to_int(client_signature))

  -- ServerKey := HMAC(SaltedPassword, "Server Key")
  local server_key = hmac.digest('sha256', salted_password .. 'Server Key', true)

  -- ServerSignature := HMAC(ServerKey, AuthMessage)
  local server_signature = hmac.digest('sha256', server_key .. auth_message, true)

  -- send the third client message
  -- {
  --   "authentication": "c=biws,r=<nonce><server_nonce>,p=<proof>"
  -- }
  raw_socket.send(encode(r, {
    authentication =
    client_final_message_without_proof ..
    ',p=' .. b64(r, client_proof)
  }), '\0')

  -- wait for the third server challenge
  -- this is always a json document
  -- {
  --   "success": <bool>,
  --   "authentication": "v=<server_signature>"
  -- }
  response, buffer = raw_socket.decode_message(buffer)

  if not response then
    return nil, buffer
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
