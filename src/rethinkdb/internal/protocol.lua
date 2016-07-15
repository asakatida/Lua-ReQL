--- Interface to handle single message protocol details.
-- @module rethinkdb.internal.protocol
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local bytes_to_int = require'rethinkdb.internal.bytes_to_int'
local int_to_bytes = require'rethinkdb.internal.int_to_bytes'
local ltn12 = require('ltn12')
local protodef = require'rethinkdb.internal.protodef'
local socket = require'rethinkdb.internal.socket'

local unpack = _G.unpack or table.unpack

local Query = protodef.Query

local CONTINUE = '[' .. Query.CONTINUE .. ']'
local NOREPLY_WAIT = '[' .. Query.NOREPLY_WAIT .. ']'
local SERVER_INFO = '[' .. Query.SERVER_INFO .. ']'
local STOP = '[' .. Query.STOP .. ']'

local START = Query.START

local nil_table = {}

--- convert from internal represention to JSON
local function build(term)
  if type(term) ~= 'table' then return term end
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

local function tokens()
  local next_token = 1

  local function get_token()
    local token
    token, next_token = next_token, next_token + 1
    return token
  end

  return get_token
end

local function get_response(ctx)
  if ctx.response_length then
    if string.len(ctx.buffer) < ctx.response_length then
      return
    end
    local response = string.sub(ctx.buffer, 1, ctx.response_length)
    ctx.buffer = string.sub(ctx.buffer, ctx.response_length + 1)
    ctx.response_length = nil
    return {ctx.token, response}
  end
  if string.len(ctx.buffer) < 12 then
    return
  end
  ctx.token = bytes_to_int(string.sub(ctx.buffer, 1, 8))
  ctx.response_length = bytes_to_int(string.sub(ctx.buffer, 9, 12))
  ctx.buffer = string.sub(ctx.buffer, 13)
end

local function buffer_response(ctx, chunk)
  if chunk then
    ctx.buffer = ctx.buffer .. chunk
  else
    local expected_length = ctx.response_length or 12
    if string.len(ctx.buffer) < expected_length then
      ctx.buffer = ''
      ctx.response_length = nil
      return nil, ctx
    end
  end
  return get_response(ctx) or nil_table, ctx
end

local function protocol(r, handshake, host, port, ssl_params, timeout, responses)
  local socket_inst, init_err = socket(r, host, port, ssl_params, timeout)

  if not socket_inst then
    return nil, init_err
  end

  local init_success

  init_success, init_err = handshake(socket_inst)

  if not init_success then
    return nil, init_err
  end

  local ctx = {buffer = ''}
  local filter = ltn12.filter.cycle(buffer_response, ctx)

  local function source()
    return ltn12.source.chain(socket_inst.source(ctx.response_length or 12), filter)
  end

  local function sink(chunk, err)
    if not chunk then
      return nil, err
    end
    local token, response = unpack(chunk)
    if token then
      responses[token] = response
    end
    return true
  end

  local function write_socket(token, data)
    data = table.concat{int_to_bytes(token, 8), int_to_bytes(string.len(data), 4), data}
    local success, err = ltn12.pump.all(ltn12.source.string(data), socket_inst.sink)
    if not success then
      return nil, err
    end
    -- buffer_response()
    return token
  end

  local get_token = tokens()

  local protocol_inst = {r = r}

  function protocol_inst.send_query(term, global_opts)
    for k, v in pairs(global_opts) do
      global_opts[k] = build(v)
    end

    -- Assign token
    local data = r.encode{START, build(term), global_opts}
    return write_socket(get_token(), data)
  end

  function protocol_inst.close()
    socket_inst.close()
  end

  function protocol_inst.continue_query(token)
    return write_socket(token, CONTINUE)
  end

  function protocol_inst.end_query(token)
    return write_socket(token, STOP)
  end

  function protocol_inst.noreply_wait()
    return write_socket(get_token(), NOREPLY_WAIT)
  end

  function protocol_inst.server_info()
    return write_socket(get_token(), SERVER_INFO)
  end

  function protocol_inst.step()
    local success, err = ltn12.pump.step(source(), sink)
    if success then
      return true
    end
    return nil, err
  end

  return protocol_inst
end

return protocol
