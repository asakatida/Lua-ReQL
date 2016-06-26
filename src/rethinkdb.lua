--- Main interface combining public modules in an export table.
-- @module rethinkdb
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016
-- @alias r

local convert_pseudotype = require'rethinkdb.convert_pseudotype'
local current_handshake = require'rethinkdb.current_handshake'
local handshake = require'rethinkdb.handshake'
local int_to_bytes = require'rethinkdb.int_to_bytes'
local protocol = require'rethinkdb.protocol'
local protodef = require'rethinkdb.protodef'
local utilities = require'rethinkdb.utilities'

local v = require('rethinkdb.semver')

local unpack = _G.unpack or table.unpack

local Term = protodef.Term

local Response = protodef.Response

local COMPILE_ERROR = Response.COMPILE_ERROR
local SUCCESS_ATOM = Response.SUCCESS_ATOM
local SUCCESS_PARTIAL = Response.SUCCESS_PARTIAL
local SUCCESS_SEQUENCE = Response.SUCCESS_SEQUENCE
local CLIENT_ERROR = Response.CLIENT_ERROR
local RUNTIME_ERROR = Response.RUNTIME_ERROR
local WAIT_COMPLETE = Response.WAIT_COMPLETE

local DEFAULT_HOST = 'localhost'
local DEFAULT_PORT = 28015
local DEFAULT_USER = 'admin'
local DEFAULT_AUTH_KEY = ''
local DEFAULT_TIMEOUT = 0.1 -- In seconds

local function proto_V0_x(raw_socket, auth_key, magic)
  -- Initialize connection with magic number to validate version
  local size, send_err = raw_socket.send(
    magic,
    int_to_bytes(#auth_key, 4),
    auth_key,
    '\199\112\105\126'
  )
  if not size then
    return nil, send_err
  end

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  local message, err = raw_socket.get_success()

  if message then
    -- We're good, finish setting up the connection
    return true
  end
  return nil, err
end

--- Interface to the ReQL error heiarchy.
-- @module rethinkdb.errors
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

--- get debug represention of query
-- @tab _args represention of arguments
-- @tab[opt] _optargs represention of options
-- @treturn string
local function compose(term, args, optargs)
  if term.st == 'datum' then
    if term.args[1] == nil then
      return 'nil'
    end
    return term.r.encode(term.args[1])
  end
  if term.st == 'make_array' then
    local res = {}
    for first, second in ipairs(args) do
      res[first] = second .. ','
    end
    return {'{', res, '\n}'}
  end
  local function kved()
    local res = {}
    for first, second in pairs(optargs) do
      table.insert(res, first .. ' = ' .. second)
    end
    return '{\n  ' .. table.concat(res, ',\n  ') .. '\n}'
  end
  if term.st == 'make_obj' then
    return kved()
  end
  if term.st == 'var' then
    return 'var_' .. args[1]
  end
  if term.st == 'binary' and not term.args[1] then
    return 'r.binary(<data>)'
  end
  if term.st == 'bracket' then
    return table.concat{args[1], '(', args[2], ')'}
  end
  if term.st == 'func' then
    local res = {}
    for first, second in ipairs(term.args[1]) do
      res[first] = 'var_' .. second
    end
    return table.concat{
      'function(',
      table.concat(res, ', '),
      ') return ', args[2], ' end'
    }
  end
  if term.st == 'do_' then
    local func = table.remove(args, 1)
    if func then
      table.insert(args, func)
    end
  end
  local argrepr = {}
  if args and next(args) then
    table.insert(argrepr, table.concat(args, ','))
  end
  if optargs and next(optargs) then
    table.insert(argrepr, kved())
  end
  return table.concat{'r.', term.st, '(', table.concat(argrepr, ', '), ')'}
end

local carrot_marker = {}

local function carrotify(tree)
  return {carrot_marker, tree}
end

local function compose_term(term)
  if type(term) ~= 'table' then return tostring(term) end
  local args = {}
  for i, arg in ipairs(term.args) do
    args[i] = compose_term(arg)
  end
  local optargs = {}
  for key, arg in pairs(term.optargs) do
    optargs[key] = compose_term(arg)
  end
  return compose(term, args, optargs)
end

local function compose_carrots(term, frames)
  local frame = table.remove(frames, 1)
  local args = {}
  for i, arg in ipairs(term.args) do
    if frame == (i - 1) then
      args[i] = compose_carrots(arg, frames)
    else
      args[i] = compose_term(arg)
    end
  end
  local optargs = {}
  for key, arg in pairs(term.optargs) do
    if frame == key then
      optargs[key] = compose_carrots(arg, frames)
    else
      optargs[key] = compose_term(arg)
    end
  end
  if frame then
    return compose(term, args, optargs)
  end
  return carrotify(compose(term, args, optargs))
end

local function join_tree(tree)
  local str = ''
  for _, term in ipairs(tree) do
    if type(term) == 'table' then
      if #term == 2 and term[1] == carrot_marker then
        str = str .. string.gsub(join_tree(term[2]), '.', '^')
      else
        str = str .. join_tree(term)
      end
    else
      str = str .. term
    end
  end
  return str
end

local function print_query(term, frames)
  local carrots
  if next(frames) then
    carrots = compose_carrots(term, frames)
  else
    carrots = {carrotify(compose_term(term))}
  end
  carrots = string.gsub(join_tree(carrots), '[^%^]', '')
  return join_tree(compose_term(term)) .. '\n' .. carrots
end

local heiarchy = {
  ReQLDriverError = 'ReQLError',

  ReQLAuthError = 'ReQLDriverError',

  ReQLServerError = 'ReQLError',

  ReQLCompileError = 'ReQLServerError',
  ReQLRuntimeError = 'ReQLServerError',
  ReQLClientError = 'ReQLServerError',

  ReQLAvailabilityError = 'ReQLRuntimeError',
  ReQLQueryLogicError = 'ReQLRuntimeError',
  ReQLInternalError = 'ReQLRuntimeError',
  ReQLResourceLimitError = 'ReQLRuntimeError',
  ReQLTimeoutError = 'ReQLRuntimeError',
  ReQLUserError = 'ReQLRuntimeError',

  ReQLOpFailedError = 'ReQLAvailabilityError',
  ReQLOpIndeterminateError = 'ReQLAvailabilityError',

  ReQLNonExistenceError = 'ReQLQueryLogicError'
}

local error_inst_meta_table = {}

function error_inst_meta_table.__tostring(err)
  return err.message()
end

local errors_meta_table = {}

local errors = setmetatable({}, errors_meta_table)

function errors_meta_table.__index(r, name)
  local function ReQLError(msg, term, frames)
    local error_inst = setmetatable({r = r, msg = msg}, error_inst_meta_table)

    local _name = name
    while _name do
      error_inst[_name] = error_inst
      _name = rawget(heiarchy, _name)
    end

    function error_inst.message()
      local _message = name .. ' ' .. error_inst.msg
      if term then
        _message = _message .. ' in:\n' .. print_query(term, frames)
      end
      function error_inst.message()
        return _message
      end
      return _message
    end

    return error_inst
  end

  return ReQLError
end

--- Interface for concrete connections.
local function connection_instance(r, handshake_inst, host, port, ssl_params, timeout)
  local db = nil
  local outstanding_callbacks = {}
  local protocol_inst = nil

  local function reset(err)
    db = nil
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
    db = r.reql.db(_db)
  end

  local function get_response(reqest_token)
    -- Buffer data, execute return results if need be
    local token, response, err
    while true do
      token, response = protocol_inst.get_response()
      if not token then
        return response
      end
      protocol_inst.continue_query(token)
      response, err = r.decode(response)
      if err and not response then
        return nil, err
      end
      if token == reqest_token then return response end
      process_response(response, token)
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

    function cursor_inst.set(callback)
      _callback = callback
    end

    function cursor_inst.close(callback)
      if not end_flag then
        end_flag = true
        if protocol_inst then
          protocol_inst.end_query(token)
          del_query(token)
        end
      end
      if callback then return callback() end
    end

    function cursor_inst.each(callback, on_finished)
      local e
      local function cb(err, data)
        if err then
          e = err
          return
        end
        return callback(data)
      end
      cursor_inst.set(cb)
      while not end_flag do
        local response, err = get_response(token)
        if err and not response then
          cb(errors.ReQLDriverError(err))
          break
        end
        add_response(response)
      end
      if on_finished then
        return on_finished(e)
      end
    end

    function cursor_inst.next(callback)
      local old_callback = _callback
      local res = nil
      local function on_data(data)
        cursor_inst.set(old_callback)
        res = {callback(nil, data)}
      end
      local function on_err(err)
        cursor_inst.set(old_callback)
        if res and not err then return unpack(res) end
        return callback(err)
      end
      return cursor_inst.each(on_data, on_err)
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
    if not protocol_inst then return cb(errors.ReQLDriverError'Connection is closed.') end

    -- Set global options
    local global_opts = {}

    for first, second in pairs(opts) do
      global_opts[first] = r.reql(second)
    end

    if opts.db then
      global_opts.db = r.reql.db(opts.db)
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

    if callback then
      return callback()
    end
  end

  function conn_inst.connect(callback)
    local err

    protocol_inst, err = protocol(r, handshake_inst, host, port, ssl_params, timeout)

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
        protocol_inst.close()
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
      return nil, err
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
    local function cb(err)
      if callback then
        return callback(err)
      end
      return nil, err
    end
    if not conn_inst.is_open() then return cb(errors.ReQLDriverError'Connection is closed.') end

    -- Construct query
    local token, err = protocol_inst.server_info()

    if not token then
      return cb(err)
    end

    return make_cursor(token).next(callback)
  end

  return conn_inst
end

local function new(driver_options)
  driver_options = driver_options or {}

  -- r is both the main export table for the module
  -- and a function that wraps a native Lua value in a ReQL datum
  local r = {}

  r.b64 = utilities.b64(driver_options)
  r.decode = utilities.decode(driver_options)
  r.encode = utilities.encode(driver_options)
  r.new = new
  r.proto_V1_0 = current_handshake
  r.r = r
  r.select = utilities._select(driver_options)
  r.socket = utilities.socket(driver_options)
  r.unb64 = utilities.unb64(driver_options)
  r.version = v'1.0.0'
  r._VERSION = r.version

  --- meta table for reql
  -- @func __index
  -- @table meta_table
  local meta_table = {}

  --- meta table driver module
  -- @func __call
  -- @func __index
  -- @table reql_meta_table
  local reql_meta_table = {}

  --- wrap lua value
  -- @tab reql driver ast module
  -- @param[opt] val lua value to wrap
  -- @int[opt=20] nesting_depth max depth of value recursion
  -- @treturn table reql
  -- @raise Cannot insert userdata object into query
  -- @raise Cannot insert thread object into query
  function reql_meta_table.__call(reql, val, nesting_depth)
    if not nesting_depth then
      nesting_depth = 20
    end
    if type(nesting_depth) ~= 'number' then
      return nil, errors.ReQLDriverError'Second argument to `r(val, nesting_depth)` must be a number.'
    end
    if nesting_depth <= 0 then
      return nil, errors.ReQLDriverError'Nesting depth limit exceeded'
    end
    if type(val) == 'userdata' then
      return nil, errors.ReQLDriverError'Cannot insert userdata object into query'
    end
    if type(val) == 'thread' then
      return nil, errors.ReQLDriverError'Cannot insert thread object into query'
    end
    if getmetatable(val) == meta_table then
      return val
    end
    if type(val) == 'function' then
      return reql.func(val)
    end
    if type(val) == 'table' then
      local array = true
      for first, second in pairs(val) do
        if type(first) ~= 'number' then array = false end
        val[first] = reql(second, nesting_depth - 1)
      end
      if array then
        return reql.make_array(unpack(val))
      end
      return reql.make_obj(val)
    end
    return reql.datum(val)
  end

  --- creates a top level term
  -- @tab _ driver ast module
  -- @string st reql term name
  -- @treturn table reql
  function reql_meta_table.__index(_, st)
    return meta_table.__index(nil, st)
  end

  --- module export
  -- @table reql
  r.reql = setmetatable({}, reql_meta_table)

  --- terms that take no options as final arguments
  local function no_opts(cls, ...)
    return {}, {cls, ...}
  end

  --- terms that take a variable number of arguments and an optional final argument that is a table of options
  local function get_opts(cls, ...)
    local args = {cls, ...}
    local opt = {}
    local pos_opt = args[#args]
    if (type(pos_opt) == 'table') and (getmetatable(pos_opt) ~= meta_table) then
      opt = pos_opt
      args[#args] = nil
    end
    return opt, args
  end

  --- terms that take 1 argument and an optional final argument that is a table of options
  local function arity_1(cls, arg0, opts)
    return opts or {}, {cls, arg0}
  end

  --- terms that take 2 arguments and an optional final argument that is a table of options
  local function arity_2(cls, arg0, arg1, opts)
    return opts or {}, {cls, arg0, arg1}
  end

  --- terms that take 3 arguments and an optional final argument that is a table of options
  local function arity_3(cls, arg0, arg1, arg2, opts)
    return opts or {}, {cls, arg0, arg1, arg2}
  end

  --- int incremented to keep reql function arguments unique
  local next_var_id = 0

  --- mapping from reql term names to argument signatures
  local arg_wrappers = {
    between = arity_3,
    between_deprecated = arity_3,
    changes = get_opts,
    circle = get_opts,
    delete = get_opts,
    distance = get_opts,
    distinct = get_opts,
    during = arity_3,
    eq_join = get_opts,
    filter = arity_2,
    fold = get_opts,
    get_all = get_opts,
    get_intersecting = get_opts,
    get_nearest = get_opts,
    group = get_opts,
    http = arity_2,
    index_create = get_opts,
    index_rename = get_opts,
    insert = arity_2,
    iso8601 = get_opts,
    js = get_opts,
    max = get_opts,
    min = get_opts,
    order_by = get_opts,
    random = get_opts,
    reconfigure = arity_1,
    reduce = get_opts,
    replace = arity_2,
    slice = get_opts,
    table = get_opts,
    table_create = get_opts,
    union = get_opts,
    update = arity_2,
    wait = arity_1
  }

  --- returns a chained term
  -- @tab cls term to chain this operation on
  -- @string st reql term name
  -- @treturn function @{reql_term}
  -- @treturn nil if there is no known term
  function meta_table.__index(cls, st)
    if st == 'run' then
      return rawget(cls, st)
    end
    local tt = rawget(Term, st)
    if not tt then
      return nil
    end

    --- instantiates a chained term
    local function reql_term(...)
      local __optargs, __args = (arg_wrappers[st] or no_opts)(cls, ...)

      if st == 'func' then
        local func = __args[1]
        local anon_args = {}
        local arg_nums = {}
        if debug.getinfo then
          local func_info = debug.getinfo(func)
          if func_info.what == 'Lua' and func_info.nparams then
            __optargs.arity = func_info.nparams
          end
        end
        for _=1, __optargs.arity or 1 do
          table.insert(arg_nums, next_var_id)
          table.insert(anon_args, r.reql.var({}, next_var_id))
          next_var_id = next_var_id + 1
        end
        func = func(unpack(anon_args))
        if func == nil then
          return nil, errors.ReQLDriverError'Anonymous function returned `nil`. Did you forget a `return`?'
        end
        __optargs.arity = nil
        __args = {arg_nums, func}
      elseif st == 'binary' then
        local data = __args[1]
        if type(data) == 'string' then
          __args[1] = {
            ['$reql_type$'] = 'BINARY',
            data = r.b64(data)
          }
        elseif r.type(data) ~= 'reql' then
          return nil, errors.ReQLDriverError'Parameter to `r.binary` must be a string or ReQL query.'
        end
      elseif st == 'datum' then
        local val = __args[1]
        if type(val) == 'number' then
          if math.abs(val) == math.huge or val ~= val then
            return nil, errors.ReQLDriverError('Illegal non-finite number `' .. val .. '`.')
          end
        end
        __args = {val}
        __optargs = {}
      elseif st == 'funcall' then
        local func = table.remove(__args)
        if type(func) == 'function' then
          func = r.reql.func({arity = #__args}, func)
        end
        table.insert(__args, 1, func)
      elseif st == 'reduce' then
        __args[#__args] = r.reql.func({arity = 2}, __args[#__args])
      end

      local reql_inst = setmetatable({
        args = {cls}, optargs = {}, r = r, st = st, tt = tt}, meta_table)

      for _, a in ipairs(__args) do
        table.insert(reql_inst.args, r.reql(a))
      end

      for first, second in pairs(__optargs) do
        reql_inst.optargs[first] = r.reql(second)
      end

      --- send term to server for evaluation
      -- @tab connection
      -- @tab[opt] options
      -- @func[opt] callback
      function reql_inst.run(connection, options, callback)
        -- Handle run(connection, callback)
        if type(options) == 'function' then
          if callback ~= nil then
            return nil, errors.ReQLDriverError'Second argument to `run` cannot be a function if a third argument is provided.'
          end
          callback = options
          options = {}
        end
        -- else we suppose that we have run(connection[, options][, callback])

        return connection._start(reql_inst, callback, options or {})
      end

      return reql_inst
    end

    return reql_term
  end

  --- get index query on server
  function meta_table.__call(term, ...)
    return term.bracket(...)
  end

  --- get count on server
  function meta_table.__len(term)
    return term.count()
  end

  --- reql math term
  function meta_table.__add(term, ...)
    return term.add(...)
  end

  --- reql math term
  function meta_table.__mul(term, ...)
    return term.mul(...)
  end

  --- reql math term
  function meta_table.__mod(term, ...)
    return term.mod(...)
  end

  --- reql math term
  function meta_table.__sub(term, ...)
    return term.sub(...)
  end

  --- reql math term
  function meta_table.__div(term, ...)
    return term.div(...)
  end

  function r.connect(host, callback)
    if type(host) == 'function' then
      callback = host
      host = {}
    elseif type(host) == 'string' then
      host = {host = host}
    end
    return r.Connector(host).connect(callback)
  end

  --- Interface to handle default connection construction.
  function r.Connector(connection_opts)
    local auth_key = connection_opts.password or connection_opts.auth_key or DEFAULT_AUTH_KEY
    local db = connection_opts.db -- left nil if this is not set
    local host = connection_opts.host or DEFAULT_HOST
    local port = connection_opts.port or DEFAULT_PORT
    local proto_version = connection_opts.proto_version or current_handshake
    local ssl_params = connection_opts.ssl
    local timeout = connection_opts.timeout or DEFAULT_TIMEOUT
    local user = connection_opts.user or DEFAULT_USER

    local handshake_inst = handshake(auth_key, proto_version, user)

    local connector_inst_meta_table = {}

    function connector_inst_meta_table.__tostring()
      return 'rethinkdb connection to ' .. host .. ':' .. port
    end

    local connector_inst = setmetatable({r = r}, connector_inst_meta_table)

    function connector_inst.connect(callback)
      if callback then
        local function cb(err, conn)
          if err then
            return callback(err)
          end
          conn.use(db)
          return callback(nil, conn)
        end
        return connection_instance(
          connector_inst.r,
          handshake_inst,
          host,
          port,
          ssl_params,
          timeout
        ).connect(cb)
      end

      local conn, err = connection_instance(
        connector_inst.r,
        handshake_inst,
        host,
        port,
        ssl_params,
        timeout
      ).connect()
      if err then
        return nil, err
      end
      conn.use(db)
      return conn
    end

    function connector_inst._start(term, callback, opts)
      local function cb(err, conn)
        if err then
          if callback then
            return callback(err)
          end
          return nil, err
        end
        conn.use(db)
        return conn._start(term, callback, opts)
      end
      return connector_inst.connect(cb)
    end

    function connector_inst.use(_db)
      db = _db
    end

    return connector_inst
  end

  function r.proto_V0_3(raw_socket, auth_key)
    return proto_V0_x(raw_socket, auth_key, '\62\232\117\95')
  end

  function r.proto_V0_4(raw_socket, auth_key)
    return proto_V0_x(raw_socket, auth_key, '\32\45\12\64')
  end

  --- Helper to determine type of public interface.
  function r.type(obj)
    if type(obj) ~= 'table' then return nil end
    if not getmetatable(obj) then return nil end
    if type(obj.r) ~= 'table' then return nil end

    if type(obj.run) == 'function' then
      return 'reql'
    end

    if type(obj._start) == 'function' and type(obj.use) == 'function' then
      if type(obj.noreply_wait) == 'function' then
        return 'connection'
      end

      return 'connector'
    end

    if type(obj.each) == 'function' and type(obj.to_array) == 'function' then
      return 'cursor'
    end

    if obj.ReQLError then
      return 'error'
    end

    return nil
  end

  return r
end

return new()
