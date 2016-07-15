--- Interface
-- @module rethinkdb.reql
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local errors = require'rethinkdb.errors'
local protodef = require'rethinkdb.internal.protodef'

local unpack = _G.unpack or table.unpack

local Term = protodef.Term

local m = {}

function m.init(r)
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
          callback, options = options, callback
        end
        -- else we suppose that we have run(connection[, options[, callback]])

        return connection._start(reql_inst, options or {}, callback)
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
end

return m
