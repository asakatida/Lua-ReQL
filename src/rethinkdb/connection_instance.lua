--- Interface for concrete connections.
-- @module rethinkdb.connection_instance

local utilities = require'rethinkdb.utilities'

local logger = utilities.logger
local encode = utilities.encode
local decode = utilities.decode

local bytes_to_int = require'rethinkdb.bytes_to_int'
local Cursor = require'rethinkdb.cursor'
local errors = require'rethinkdb.errors'
local int_to_bytes = require'rethinkdb.int_to_bytes'
local proto = require'rethinkdb.protodef'
local Socket = require'rethinkdb.socket'

local Query = proto.Query

local CONTINUE = '[' .. Query.CONTINUE .. ']'
local NOREPLY_WAIT = '[' .. Query.NOREPLY_WAIT .. ']'
local SERVER_INFO = '[' .. Query.SERVER_INFO .. ']'
local STOP = '[' .. Query.STOP .. ']'

local START = Query.START

return function(r, auth_key, db, host, port, proto_version, ssl_params, timeout, user)
  local raw_socket = Socket(r, host, port, ssl_params, timeout)
  local outstanding_callbacks = {}
  local next_token = 1
  local buffer = ''

  local function write_socket(token, data)
    return raw_socket.send(
      int_to_bytes(token, 8),
      int_to_bytes(#data, 4),
      data
    )
  end

  local function send_query(token, query)
    local data = encode(r, query)
    return write_socket(token, data)
  end

  local function continue_query(token)
    return write_socket(token, CONTINUE)
  end

  local function del_query(token)
    -- This query is done, delete this cursor
    if not outstanding_callbacks[token] then return end
    outstanding_callbacks[token].cursor = nil
  end

  local function end_query(token)
    del_query(token)
    return write_socket(token, STOP)
  end

  local function process_response(response, token)
    local cursor = outstanding_callbacks[token]
    if not cursor then
      -- Unexpected token
      return nil, 'Unexpected token ' .. token
    end
    local add_response = cursor.add_response
    cursor = cursor.cursor
    if cursor then
      return add_response(response)
    end
  end

  local function use(_db)
    db = r.db(_db).build()
  end

  if db then use(db) end

  local inst = {
    is_open = raw_socket.is_open,
    use = use
  }

  local function get_response(reqest_token)
    -- Buffer data, execute return results if need be
    while true do
      local buf, err = raw_socket.recv()
      if err then
        raw_socket.close()
        buffer = ''
        return err
      end
      buffer = buffer .. buf
      local buffer_len = #buffer
      if buffer_len >= 12 then
        local token = bytes_to_int(string.sub(buffer, 1, 8))
        local response_length = bytes_to_int(string.sub(buffer, 9, 12)) + 13
        if buffer_len >= response_length then
          local response_buffer = string.sub(buffer, 13, response_length)
          continue_query(token)
          process_response(decode(r, response_buffer), token)
          buffer = string.sub(buffer, response_length + 1)
          if token == reqest_token then return end
        end
      end
    end
  end

  local function make_cursor(token, opts, term)
    local cursor, add_response = Cursor(
       r, del_query, end_query, get_response, token, opts or {}, term)

    -- Save cursor

    outstanding_callbacks[token] = {
      cursor = cursor,
      add_response = add_response
    }

    return cursor
  end

  function inst._start(term, callback, opts)
    local function cb(err, cur)
      local res
      if type(callback) == 'function' then
        res = callback(err, cur)
      else
        if err then
          return nil, err
        end
      end
      cur.close()
      return res
    end
    if not inst.is_open() then
      return cb(errors.ReQLDriverError('Connection is closed.'))
    end

    -- Assign token
    local token = next_token
    next_token = next_token + 1

    -- Set global options
    local global_opts = {}

    for k, v in pairs(opts) do
      global_opts[k] = r(v).build()
    end

    if opts.db then
      global_opts.db = opts.db.db().build()
    elseif db then
      global_opts.db = db
    end

    if type(callback) ~= 'function' then
      global_opts.noreply = true
    end

    -- Construct query
    local query = {START, term.build(), global_opts}

    local _, err = send_query(token, query)

    if err then
      raw_socket.close()
      buffer = ''
      return cb(err)
    end

    return cb(nil, make_cursor(token, opts, term))
  end

  function inst.close(opts_or_callback, callback)
    local opts = {}
    if callback then
      if type(opts_or_callback) ~= 'table' then
        return logger(r, 'First argument to two-argument `close` must be a table.')
      end
      opts = opts_or_callback
    elseif type(opts_or_callback) == 'table' then
      opts = opts_or_callback
    elseif type(opts_or_callback) == 'function' then
      callback = opts_or_callback
    end

    local function cb(err)
      raw_socket.close()
      buffer = ''
      if callback then
        return callback(err)
      end
      return err
    end

    local noreply_wait = (opts.noreply_wait ~= false) and inst.is_open()

    if noreply_wait then
      return inst.noreply_wait(cb)
    end
    return cb()
  end

  function inst.connect(callback)
    local function error_(err)
      raw_socket.close()
      buffer = ''
      err = errors.ReQLDriverError(
        'Could not connect to ' .. host .. ':' .. port .. '.\n' .. err)
      if callback then
        return callback(err)
      end
      return nil, err
    end

    local err = raw_socket.open()

    if err then
      return error_(err)
    end

    buffer, err = proto_version(r, raw_socket, auth_key, user)

    if err then
      return error_(err)
    end

    if callback then
      local res = callback(nil, inst)
      raw_socket.close()
      buffer = ''
      return res
    end

    return inst
  end

  function inst.noreply_wait(callback)
    local function cb(_err, _cur)
      if _cur then
        return _cur.next(function(err)
          return callback(err)
        end)
      end
      return callback(_err)
    end
    if not inst.is_open() then
      return cb(errors.ReQLDriverError('Connection is closed.'))
    end

    -- Assign token
    local token = next_token
    next_token = next_token + 1

    local cursor = make_cursor(token)

    -- Construct query
    write_socket(token, NOREPLY_WAIT)

    return cb(nil, cursor)
  end

  function inst.reconnect(opts_or_callback, callback)
    local opts = {}
    if callback or not type(opts_or_callback) == 'function' then
      opts = opts_or_callback
    else
      callback = opts_or_callback
    end
    inst.close(opts)
    return inst.connect(callback)
  end

  function inst.server()
    if not inst.is_open() then
      return nil, errors.ReQLDriverError('Connection is closed.')
    end

    -- Assign token
    local token = next_token
    next_token = next_token + 1

    local cursor = make_cursor(token)

    -- Construct query
    write_socket(token, SERVER_INFO)

    return cursor.next(function(err, res)
      if err then return nil, err end
      return res
    end)
  end

  return inst
end
