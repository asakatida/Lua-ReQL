--- Interface for concrete connections.
-- @module rethinkdb.connection_instance
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local cursor = require'rethinkdb.cursor'
local errors = require'rethinkdb.errors'
local protocol = require'rethinkdb.internal.protocol'

local function connection_instance(r, handshake_inst, host, port, ssl_params, timeout)
  local db = nil
  local outstanding_callbacks = {}
  local protocol_inst = nil
  local responses = {}

  local function reset(err)
    db = nil
    protocol_inst.close()
    protocol_inst = nil
    for _, cursor_inst in ipairs(outstanding_callbacks) do
      cursor_inst.close()
    end
    outstanding_callbacks = {}
    if type(err) == 'string' then
      return nil, errors.ReQLDriverError(err)
    end
    return nil, err
  end

  local function del_query(token)
    -- This query is done, delete this cursor
    outstanding_callbacks[token] = nil
  end

  local conn_inst_meta_table = {}

  function conn_inst_meta_table.__tostring()
    return (
      protocol_inst and 'open' or 'closed'
    ) .. ' rethinkdb connection to ' .. host .. ':' .. port
  end

  local conn_inst = setmetatable(
    {host = host, port = port, r = r}, conn_inst_meta_table)

  function conn_inst.is_open()
    return protocol_inst and true or false
  end

  function conn_inst.use(_db)
    db = conn_inst.r.reql.db(_db)
  end

  local function step(token)
    -- Buffer data, execute return results if need be
    while not responses[token] do
      local success, err = protocol_inst.step()
      if not success then
        return reset(err)
      end
    end
    protocol_inst.continue_query(token)

    local response, err = nil
    response, responses[token] = responses[token], response
    response, err = conn_inst.r.decode(response)
    if err and not response then
      return reset(err)
    end

    local add_response = outstanding_callbacks[token]
    if not add_response then
      return reset('Unexpected token ' .. token)
    end
    return add_response(response)
  end

  local function make_cursor(token, opts, term)
    local cursor_inst, add_response = cursor(token, del_query, opts or {}, step, protocol_inst, term)

    -- Save cursor
    outstanding_callbacks[token] = add_response

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
    local token, err = protocol_inst.send_query(reql_inst, global_opts)

    if err then
      return cb(err)
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
    local err

    protocol_inst, err = protocol(r, handshake_inst, host, port, ssl_params, timeout, responses)

    if not protocol_inst then
      if type(err) == 'table' then
        if 10 <= err.error_code and err.error_code <= 20 then
          return reset(errors.ReQLAuthError(err.error))
        end
        return reset(err.error)
      end
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

    return make_cursor(token).next(callback)
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
    end
    if not conn_inst.is_open() then return cb(errors.ReQLDriverError'Connection is closed.') end

    -- Construct query
    local token, err = protocol_inst.server_info()

    if not token then
      return cb(err)
    end

    return make_cursor(token).next(cb)
  end

  return conn_inst
end

return connection_instance
