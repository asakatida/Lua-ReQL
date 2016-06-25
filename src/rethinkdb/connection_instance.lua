--- Interface for concrete connections.
-- @module rethinkdb.connection_instance
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local convert_pseudotype = require'rethinkdb.convert_pseudotype'
local errors = require'rethinkdb.errors'
local proto = require'rethinkdb.protodef'
local protocol = require'rethinkdb.protocol'

local Response = proto.Response

local COMPILE_ERROR = Response.COMPILE_ERROR
local SUCCESS_ATOM = Response.SUCCESS_ATOM
local SUCCESS_PARTIAL = Response.SUCCESS_PARTIAL
local SUCCESS_SEQUENCE = Response.SUCCESS_SEQUENCE
local CLIENT_ERROR = Response.CLIENT_ERROR
local RUNTIME_ERROR = Response.RUNTIME_ERROR
local WAIT_COMPLETE = Response.WAIT_COMPLETE

local function connection_instance(r, handshake, host, port, ssl_params, timeout)
  local db = nil
  local outstanding_callbacks = {}
  local protocol_inst = nil

  local function reset(err)
    db = nil
    outstanding_callbacks = {}
    protocol_inst = nil
    if type(err) == 'string' then
      return nil, errors.ReQLDriverError(err)
    end
    return nil, err
  end

  local function del_query(token)
    -- This query is done, delete this cursor
    outstanding_callbacks[token] = nil
  end

  local function process_response(response, token)
    local cursor = outstanding_callbacks[token]
    if not cursor then
      return reset('Unexpected token ' .. token)
    end
    local add_response = cursor.add_response
    if add_response then
      return add_response(response)
    end
  end

  local inst = {r = r}

  function inst.is_open()
    return protocol_inst and true or false
  end

  function inst.use(_db)
    db = r.reql.db(_db).build()
  end

  local function get_response(reqest_token)
    -- Buffer data, execute return results if need be
    local token, response
    while true do
      token, response = protocol_inst.get_response()
      if not token then
        return response
      end
      protocol_inst.continue_query(token)
      process_response(r.decode(response), token)
      if token == reqest_token then return end
    end
  end

  local function Cursor(token, opts, root)
    local responses = {}
    local _callback, end_flag, _type

    local cursor_inst = {r = r}

    local function run_cb(callback)
      local response = responses[1]
      if not response then return callback() end
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

        return callback(err, row)
      end
      _callback = nil
      if t == COMPILE_ERROR then
        return callback(errors.ReQLCompileError(response.r[1], root, response.b))
      elseif t == CLIENT_ERROR then
        return callback(errors.ReQLClientError(response.r[1], root, response.b))
      elseif t == RUNTIME_ERROR then
        return callback(errors.ReQLRuntimeError(response.r[1], root, response.b))
      elseif t == WAIT_COMPLETE then
        return callback()
      end
      return callback(errors.ReQLDriverError('Unknown response type ' .. t))
    end

    function cursor_inst.set(callback)
      _callback = callback
    end

    function cursor_inst.close(callback)
      if not end_flag then
        end_flag = true
        protocol_inst.end_query(token)
        del_query(token)
      end
      if callback then return callback() end
    end

    function cursor_inst.each(callback, on_finished)
      local e
      local function cb(err, data)
        e = err
        return callback(data)
      end
      cursor_inst.set(cb)
      while not end_flag do
        get_response(token)
      end
      if on_finished then
        return on_finished(e)
      end
    end

    function cursor_inst.next(callback)
      if end_flag then
        return callback(errors.ReQLDriverError'No more rows in the cursor.')
      end
      local old_callback = nil
      local function cb(err, res)
        cursor_inst.set(old_callback)
        return callback(err, res)
      end
      old_callback, _callback = _callback, old_callback
      cursor_inst.set(cb)
      get_response(token)
      return run_cb(cb)
    end

    function cursor_inst.to_array(callback)
      local arr = {}

      local function cb(row)
        table.insert(arr, row)
      end

      local function on_finished(err)
        return callback(err, arr)
      end

      return cursor_inst.each(cb, on_finished)
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
      while _callback and responses[1] do
        run_cb(_callback)
      end
    end

    return cursor_inst, add_response
  end

  local function make_cursor(token, opts, term)
    local cursor_inst, add_response = Cursor(token, opts or {}, term)

    -- Save cursor
    outstanding_callbacks[token] = {
      add_response = add_response
    }

    return cursor_inst
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
    if not protocol_inst then return cb(errors.ReQLDriverError'Connection is closed.') end

    -- Set global options
    local global_opts = {}

    for k, v in pairs(opts) do
      global_opts[k] = r.reql(v).build()
    end

    if opts.db then
      global_opts.db = r.reql.db(opts.db).build()
    elseif db then
      global_opts.db = db
    end

    if type(callback) ~= 'function' then
      global_opts.noreply = true
    end

    -- Construct query
    local token, err = protocol_inst.send_query(term, global_opts)

    if err then
      return cb(err)
    end

    return cb(nil, make_cursor(token, opts, term))
  end

  function inst.close(opts_or_callback, callback)
    local opts = {}
    if callback or type(opts_or_callback) == 'table' then
      opts = opts_or_callback
    elseif type(opts_or_callback) == 'function' then
      callback = opts_or_callback
    end

    local noreply_wait = (opts.noreply_wait ~= false) and inst.is_open()

    if noreply_wait then
      inst.noreply_wait()
    end

    if callback then
      return callback()
    end
  end

  function inst.connect(callback)
    local err

    protocol_inst, err = protocol(r, handshake, host, port, ssl_params, timeout)

    if not protocol_inst then
      return reset(err)
    end

    if callback then
      local function with(...)
        protocol_inst.close()
        reset()
        return ...
      end
      return with(callback(nil, inst))
    end

    return inst
  end

  function inst.noreply_wait(callback)
    local function cb(err)
      if callback then
        return callback(err)
      end
      return nil, err
    end
    if not inst.is_open() then return cb(errors.ReQLDriverError'Connection is closed.') end

    -- Construct query
    local token, err = protocol_inst.noreply_wait()

    if not token then
      return cb(err)
    end

    return make_cursor(token).next(callback)
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

  function inst.server(callback)
    local function cb(err)
      if callback then
        return callback(err)
      end
      return nil, err
    end
    if not inst.is_open() then return cb(errors.ReQLDriverError'Connection is closed.') end

    -- Construct query
    local token, err = protocol_inst.server_info()

    if not token then
      return cb(err)
    end

    return make_cursor(token).next(callback)
  end

  return inst
end

return connection_instance
