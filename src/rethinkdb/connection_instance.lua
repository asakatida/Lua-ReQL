--- Interface for concrete connections.
-- @module rethinkdb.connection_instance
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local utilities = require'rethinkdb.utilities'

local bytes_to_int = require'rethinkdb.bytes_to_int'
local convert_pseudotype = require'rethinkdb.convert_pseudotype'
local errors = require'rethinkdb.errors'
local int_to_bytes = require'rethinkdb.int_to_bytes'
local proto = require'rethinkdb.protodef'
local Socket = require'rethinkdb.socket'

local encode = utilities.encode
local decode = utilities.decode

local Query = proto.Query
local Response = proto.Response

local COMPILE_ERROR = Response.COMPILE_ERROR
local SUCCESS_ATOM = Response.SUCCESS_ATOM
local SUCCESS_PARTIAL = Response.SUCCESS_PARTIAL
local SUCCESS_SEQUENCE = Response.SUCCESS_SEQUENCE
local CLIENT_ERROR = Response.CLIENT_ERROR
local RUNTIME_ERROR = Response.RUNTIME_ERROR
local WAIT_COMPLETE = Response.WAIT_COMPLETE

local CONTINUE = '[' .. Query.CONTINUE .. ']'
local NOREPLY_WAIT = '[' .. Query.NOREPLY_WAIT .. ']'
local SERVER_INFO = '[' .. Query.SERVER_INFO .. ']'
local STOP = '[' .. Query.STOP .. ']'

local START = Query.START

local function connection_instance(r, auth_key, db, host, port, proto_version, ssl_params, timeout, user)
  local raw_socket = Socket(r, host, port, ssl_params, timeout)
  local outstanding_callbacks = {}
  local next_token = 1
  local buffer = ''

  local function write_socket(token, data)
    local size, err = raw_socket.send(
      int_to_bytes(token, 8),
      int_to_bytes(#data, 4),
      data
    )
    if not size then
      return nil, err
    end
    if err == '' then
      return
    end
    local buf, recv_err = raw_socket.recv()
    if recv_err then
      raw_socket.close()
      buffer = ''
      return nil, recv_err
    end
    buffer = buffer .. buf
    size, err = raw_socket.send(err)
    if not size then
      return nil, err
    end
    if err == '' then
      return
    end
    raw_socket.close()
    buffer = ''
    return nil, errors.ReQLDriverError('Incomplete write of query ' .. data)
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
    outstanding_callbacks[token] = {} -- @todo this should set to nil
  end

  local function end_query(token)
    del_query(token)
    return write_socket(token, STOP)
  end

  local function process_response(response, token)
    local cursor = outstanding_callbacks[token]
    if not cursor then
      return nil, errors.ReQLDriverError('Unexpected token ' .. token)
    end
    local add_response = cursor.add_response
    if add_response then
      return add_response(response)
    end
  end

  local conn_inst = {}

  conn_inst.is_open = raw_socket.is_open

  function conn_inst.use(_db)
    db = r.db(_db).build()
  end

  if db then conn_inst.use(db) end

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

  local function Cursor(token, opts, root)
    local responses = {}
    local _cb, end_flag, _type

    local inst = {}

    local function run_cb(cb)
      local response = responses[1]
      -- Behavior varies considerably based on response type
      -- Error responses are not discarded, and the error will be sent to all future callbacks
      local t = response.t
      if t == SUCCESS_ATOM or t == SUCCESS_PARTIAL or t == SUCCESS_SEQUENCE then
        local row, err = convert_pseudotype(r, response.r[1], opts)

        if err then
          row = response.r[1]
        end

        table.remove(response.r, 1)
        if not next(response.r) then table.remove(responses, 1) end

        return cb(err, row)
      end
      _cb = nil
      if t == COMPILE_ERROR then
        return cb(errors.ReQLCompileError(response.r[1], root, response.b))
      elseif t == CLIENT_ERROR then
        return cb(errors.ReQLClientError(response.r[1], root, response.b))
      elseif t == RUNTIME_ERROR then
        return cb(errors.ReQLRuntimeError(response.r[1], root, response.b))
      elseif t == WAIT_COMPLETE then
        return cb()
      end
      return cb(errors.ReQLDriverError('Unknown response type ' .. t))
    end

    function inst.set(cb)
      _cb = cb
    end

    function inst.close(cb)
      if not end_flag then
        end_flag = true
        end_query(token)
      end
      if cb then return cb() end
    end

    function inst.each(callback, on_finished)
      local e
      local function cb(err, data)
        e = err
        return callback(data)
      end
      inst.set(cb)
      while not end_flag do
        get_response(token)
      end
      if on_finished then
        return on_finished(e)
      end
    end

    function inst.next(callback)
      if end_flag then
        return callback(errors.ReQLDriverError('No more rows in the cursor.'))
      end
      local old_cb = nil
      local function cb(err, res)
        inst.set(old_cb)
        return callback(err, res)
      end
      old_cb, _cb = _cb, old_cb
      inst.set(cb)
      get_response(token)
      return run_cb(cb)
    end

    function inst.to_array(callback)
      local arr = {}

      local function cb(row)
        table.insert(arr, row)
      end

      local function on_finished(err)
        return callback(err, arr)
      end

      return inst.each(cb, on_finished)
    end

    local function add_response(response)
      local t = response.t
      if not _type then
        if response.n then
          _type = response.n
        else
          _type = 'finite'
        end
      end
      if response.r[1] or t == WAIT_COMPLETE then
        table.insert(responses, response)
      end
      if t ~= SUCCESS_PARTIAL then
        -- We got the final document for this cursor
        end_flag = true
        del_query(token)
      end
      while _cb and responses[1] do
        run_cb(_cb)
      end
    end

    return inst, add_response
  end

  local function make_cursor(token, opts, term)
    local cursor, add_response = Cursor(token, opts or {}, term)

    -- Save cursor

    outstanding_callbacks[token] = {
      add_response = add_response
    }

    return cursor
  end

  function conn_inst._start(term, callback, opts)
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
    if not conn_inst.is_open() then
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

  function conn_inst.close(opts_or_callback, callback)
    local opts = {}
    if callback or type(opts_or_callback) == 'table' then
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

    local noreply_wait = (opts.noreply_wait ~= false) and conn_inst.is_open()

    if noreply_wait then
      return conn_inst.noreply_wait(cb)
    end
    return cb()
  end

  function conn_inst.connect(callback)
    local function error_(err)
      raw_socket.close()
      buffer = ''
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
      local res = callback(nil, conn_inst)
      raw_socket.close()
      buffer = ''
      return res
    end

    return conn_inst
  end

  function conn_inst.noreply_wait(callback)
    local function cb(err)
      if callback then
        return callback(err)
      end
      return nil, err
    end
    if not conn_inst.is_open() then
      return cb(errors.ReQLDriverError('Connection is closed.'))
    end

    -- Assign token
    local token = next_token
    next_token = next_token + 1

    local cursor = make_cursor(token)

    -- Construct query
    write_socket(token, NOREPLY_WAIT)

    return cursor.next(callback)
  end

  function conn_inst.reconnect(opts_or_callback, callback)
    local opts = {}
    if callback or not type(opts_or_callback) == 'function' then
      opts = opts_or_callback
    else
      callback = opts_or_callback
    end
    conn_inst.close(opts)
    return conn_inst.connect(callback)
  end

  function conn_inst.server(callback)
    local function cb(err)
      if callback then
        return callback(err)
      end
      return nil, err
    end
    if not conn_inst.is_open() then
      return cb(errors.ReQLDriverError('Connection is closed.'))
    end

    -- Assign token
    local token = next_token
    next_token = next_token + 1

    local cursor = make_cursor(token)

    -- Construct query
    write_socket(token, SERVER_INFO)

    return cursor.next(callback)
  end

  return conn_inst
end

return connection_instance
