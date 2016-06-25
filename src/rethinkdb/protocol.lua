--- Interface to handle single message protocol details.
-- @module rethinkdb.protocol
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local bytes_to_int = require'rethinkdb.bytes_to_int'
local int_to_bytes = require'rethinkdb.int_to_bytes'
local protodef = require'rethinkdb.protodef'
local socket = require'rethinkdb.socket'

local Query = protodef.Query

local CONTINUE = '[' .. Query.CONTINUE .. ']'
local NOREPLY_WAIT = '[' .. Query.NOREPLY_WAIT .. ']'
local SERVER_INFO = '[' .. Query.SERVER_INFO .. ']'
local STOP = '[' .. Query.STOP .. ']'

local START = Query.START

--- convert from internal represention to JSON
local function build(term)
  if type(term) ~= 'table' then return term end
  if term.st == 'binary' and (not term.args[1]) then
    return {
      ['$reql_type$'] = 'BINARY',
      data = term.base64_data
    }
  end
  if term.st == 'datum' then
    if term.args[1] == nil then
      return term.r.encode()
    end
    return term.args[1]
  end
  if term.st == 'make_obj' then
    local res = {}
    for key, val in pairs(term.optargs) do
      res[key] = build(val)
    end
    return res
  end
  local _args = {}
  for i, arg in ipairs(term.args) do
    _args[i] = build(arg)
  end
  local res = {term.tt, _args}
  if next(term.optargs) then
    local opts = {}
    for key, val in pairs(term.optargs) do
      opts[key] = build(val)
    end
    table.insert(res, opts)
  end
  return res
end

local function protocol(r, handshake, host, port, ssl_params, timeout)
  local buffer = ''
  local next_token = 1

  local function get_token()
    local token
    token, next_token = next_token, next_token + 1
    return token
  end

  local function open()
    local socket_inst, err = socket(r, host, port, ssl_params, timeout)

    if not socket_inst then
      return nil, err
    end

    socket_inst, err = handshake(socket_inst)

    if not socket_inst then
      return nil, err
    end

    return socket_inst
  end

  local socket_inst, init_err = open()

  if not socket_inst then
    return nil, init_err
  end

  local inst = {r = r}

  local function buffer_response()
    while string.len(buffer) < 12 do
      local buf, err = socket_inst.recv(12 - string.len(buffer))
      if err then
        return nil, err
      end
      buffer = buffer .. buf
    end
    local response_length = bytes_to_int(string.sub(buffer, 9, 12)) + 12
    while string.len(buffer) < response_length do
      local buf, err = socket_inst.recv(response_length - string.len(buffer))
      if err then
        return nil, err
      end
      buffer = buffer .. buf
    end
  end

  local function write_socket(token, data)
    local size, err = socket_inst.send(
      int_to_bytes(token, 8),
      int_to_bytes(#data, 4),
      data
    )
    if not size then
      return nil, err
    end
    buffer_response()
    return token
  end

  function inst.send_query(term, global_opts)
    for k, v in pairs(global_opts) do
      global_opts[k] = build(v)
    end

    -- Assign token
    local data = r.encode{START, build(term), global_opts}
    return write_socket(get_token(), data)
  end

  function inst.continue_query()
    return write_socket(get_token(), CONTINUE)
  end

  function inst.end_query()
    return write_socket(get_token(), STOP)
  end

  function inst.noreply_wait()
    return write_socket(get_token(), NOREPLY_WAIT)
  end

  function inst.server_info()
    return write_socket(get_token(), SERVER_INFO)
  end

  function inst.query_response()
    while string.len(buffer) < 12 do
      local buf, err = socket_inst.recv(12 - string.len(buffer))
      if err then
        return nil, err
      end
      buffer = buffer .. buf
    end
    local token = bytes_to_int(string.sub(buffer, 1, 8))
    local response_length = bytes_to_int(string.sub(buffer, 9, 12))
    buffer = string.sub(buffer, 13)
    while string.len(buffer) < response_length do
      local buf, err = socket_inst.recv(response_length - string.len(buffer))
      if err then
        return nil, err
      end
      buffer = buffer .. buf
    end
    local response = string.sub(buffer, 1, response_length)
    buffer = string.sub(buffer, response_length + 1)
    return token, response
  end

  return inst
end

return protocol
