--- Interface for concrete connections.
-- @module rethinkdb.connection_instance
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local cursor = require'rethinkdb.cursor'
local errors = require'rethinkdb.errors'
local ltn12 = require('ltn12')
local protocol = require'rethinkdb.internal.protocol'
local protect = require'rethinkdb.internal.protect'
local socket = require'rethinkdb.internal.socket'

local unpack = _G.unpack or table.unpack

local function connection_instance(r, handshake_inst, host, port, ssl_params, timeout)
  local db = nil
  local outstanding_callbacks = {}
  local protocol_inst = nil
  local responses = {}

  local function reset(err)
    db = nil
    protocol_inst.close()
    protocol_inst = nil
    for _, state in pairs(outstanding_callbacks) do
      state.open = nil
    end
    outstanding_callbacks = {}
    if type(err) == 'string' then
      return nil, errors.ReQLDriverError(err)
    end
    return nil, err
  end

  local conn_inst_meta_table = {}

  function conn_inst_meta_table.__tostring(conn_inst)
    return (
      protocol_inst and 'open' or 'closed'
    ) .. ' rethinkdb connection to ' .. conn_inst.host .. ':' .. conn_inst.port
  end

  local conn_inst = setmetatable(
    {host = host, port = port, r = r}, conn_inst_meta_table)

  function conn_inst.is_open()
    return protocol_inst and true or false
  end

  function conn_inst.use(_db)
    db = conn_inst.r.reql.db(_db)
  end

  local function add_response(token, response, state)
    protocol_inst.continue_query(token)

    local err
    response, err = protect(conn_inst.r.decode, response)
    if not response then
      return reset(err)
    end

    return state.add_response(response)
  end

  local function sink(chunk, err)
    if not chunk then
      return nil, err
    end
    local token, response = unpack(chunk)
    if token then
      local state = outstanding_callbacks[token]
      if not state then
        return reset('Unexpected token ' .. token)
      end
      if state.outstanding_callback and state.open then
        response, err = add_response(token, response, state)
        if not response then
          return nil, err
        end
      else
        responses[token] = response
      end
    end
    return true
  end

  local function make_cursor(token, opts, term)
    local state = {open = true, opts = opts, term = term}

    function state.del_query()
      -- This query is done, delete this cursor
      outstanding_callbacks[token] = nil
      state.open = nil
    end

    function state.end_query()
      if protocol_inst then
        return protocol_inst.end_query(token)
      end
    end

    function state.step()
      -- Buffer data, execute return results if need be
      while not responses[token] do
        local success, err = ltn12.pump.step(protocol_inst.source(conn_inst.r), sink)
        if not success then
          return reset(err)
        end
      end
      local response = nil
      response, responses[token] = responses[token], response

      add_response(token, response, state)
    end

    local cursor_inst = cursor(conn_inst.r, state, opts, term)

    -- Save cursor shared state
    outstanding_callbacks[token] = state

    return cursor_inst
  end

  function conn_inst._start(reql_inst, options, callback)
    local function cb(err, cur)
      if type(callback) == 'function' then
        local res
        res = callback(err, cur)
        if cur then
          cur.close()
        end
        return res
      end
      return cur, err
    end
    if not protocol_inst then return cb(errors.ReQLDriverError'Connection is closed.') end

    -- Set global options
    local global_opts = {}

    for first, second in pairs(options) do
      global_opts[first] = r.reql(second)
    end

    if options.db then
      global_opts.db = r.reql.db(options.db)
    elseif db then
      global_opts.db = db
    end

    -- Construct query
    local token, err = protocol_inst.send_query(conn_inst.r, reql_inst, global_opts)

    if err then
      return cb(err)
    end

    if options.noreply then
      return true
    end

    return cb(nil, make_cursor(token, options, reql_inst))
  end

  function conn_inst.close(opts_or_callback, callback)
    local opts = {}
    if callback or type(opts_or_callback) == 'table' then
      opts = opts_or_callback
    elseif type(opts_or_callback) == 'function' then
      callback = opts_or_callback
    end

    local noreply_wait = (opts.noreply_wait ~= false) and conn_inst.is_open()

    if noreply_wait then
      conn_inst.noreply_wait()
    end

    reset()

    if callback then
      return callback()
    end
  end

  function conn_inst.connect(callback)
    local socket_inst, err = socket(conn_inst.r, conn_inst.host, conn_inst.port, ssl_params, timeout)

    if not socket_inst then
      return reset(err)
    end

    local init_success

    init_success, err = handshake_inst(conn_inst.r, socket_inst)

    if not init_success then
      if type(err) == 'table' then
        if 10 <= err.error_code and err.error_code <= 20 then
          return reset(errors.ReQLAuthError(err.error))
        end
        return reset(err.error)
      end
      return reset(err)
    end

    protocol_inst, err = protocol(socket_inst)

    if not protocol_inst then
      return reset(err)
    end

    if callback then
      local function with(...)
        reset()
        return ...
      end
      return with(callback(nil, conn_inst))
    end

    return conn_inst
  end

  function conn_inst.noreply_wait(callback)
    local function cb(err)
      if callback then
        return callback(err)
      end
      if err then
        return false, err
      end
      return true
    end
    if not conn_inst.is_open() then return cb(errors.ReQLDriverError'Connection is closed.') end

    -- Construct query
    local token, err = protocol_inst.noreply_wait()

    if not token then
      return cb(err)
    end

    return make_cursor(token).to_array(cb)
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
    local function cb(err, ...)
      if callback then
        return callback(err, ...)
      end
      if err then
        return reset(err)
      end
      return ...
    end
    if not conn_inst.is_open() then return cb(errors.ReQLDriverError'Connection is closed.') end

    -- Construct query
    local token, err = protocol_inst.server_info()

    if not token then
      return cb(err)
    end

    return make_cursor(token).to_array(cb)
  end

  return conn_inst
end

return connection_instance
