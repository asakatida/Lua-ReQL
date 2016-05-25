--- Interface to create ReQL queries.
-- @module rethinkdb.ast
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016
-- @alias r

local utilities = require'rethinkdb.utilities'

local proto = require'rethinkdb.protodef'

local logger = utilities.logger
local b64 = utilities.b64
local encode = utilities.encode

local Term = proto.Term

local _datum = Term.datum

local unpack = _G.unpack or table.unpack

--- meta table for reql
-- @func __index
-- @table meta_table
local meta_table = {}

--- meta table driver module
-- @func __call
-- @func __index
-- @table r_meta_table
local r_meta_table = {}

--- wrap lua value
-- @tab r driver module
-- @param[opt] val lua value to wrap
-- @int[opt=20] nesting_depth max depth of value recursion
-- @treturn table reql
-- @raise Cannot insert userdata object into query
-- @raise Cannot insert thread object into query
function r_meta_table.__call(r, val, nesting_depth)
  if nesting_depth == nil then
    nesting_depth = 20
  end
  if type(nesting_depth) ~= 'number' then
    return logger(r, 'Second argument to `r(val, nesting_depth)` must be a number.')
  end
  if nesting_depth <= 0 then
    return logger(r, 'Nesting depth limit exceeded')
  end
  if type(val) == 'userdata' then
    return logger(r, 'Cannot insert userdata object into query')
  end
  if type(val) == 'thread' then
    return logger(r, 'Cannot insert thread object into query')
  end
  if getmetatable(val) == meta_table then
    return val
  end
  if type(val) == 'function' then
    return r.func(val)
  end
  if type(val) == 'table' then
    local array = true
    for k, v in pairs(val) do
      if type(k) ~= 'number' then array = false end
      val[k] = r(v, nesting_depth - 1)
    end
    if array then
      return r.make_array(unpack(val))
    end
    return r.make_obj(val)
  end
  return r.datum(val)
end

--- creates a top level term
-- @tab r driver module
-- @string st reql term name
-- @treturn table reql
function r_meta_table.__index(r, st)
  return meta_table.__index(r, st)
end

--- module export
-- @table r
local r = setmetatable({}, r_meta_table)

--- pack reql arguments
local function chain(cls, ...)
  if getmetatable(cls) == r_meta_table then
    return {...}
  end
  return {cls, ...}
end

--- terms that take no options as final arguments
local function no_opts(cls, ...)
  return {}, chain(cls, ...)
end

--- terms that take a variable number of arguments and an optional final argument that is a table of options
local function get_opts(cls, ...)
  local args = chain(cls, ...)
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
  return opts or {}, chain(cls, arg0)
end

--- terms that take 2 arguments and an optional final argument that is a table of options
local function arity_2(cls, arg0, arg1, opts)
  return opts or {}, chain(cls, arg0, arg1)
end

--- terms that take 3 arguments and an optional final argument that is a table of options
local function arity_3(cls, arg0, arg1, arg2, opts)
  return opts or {}, chain(cls, arg0, arg1, arg2)
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

--- wrap a Lua string, number, or nil for reql terms
-- @param[opt] val string or finite number
-- @treturn table reql
local function datum(val)
  if type(val) == 'number' then
    if math.abs(val) == math.huge or val ~= val then
      return logger(r, 'Illegal non-finite number `' .. val .. '`.')
    end
  end

  local function build()
    if val == nil then
      return encode(r)
    end
    return val
  end

  local function compose()
    if val == nil then
      return 'nil'
    end
    return encode(r, val)
  end

  return setmetatable({
    args = {},
    build = build,
    compose = compose,
    optargs = {},
    tt = _datum,
    st = 'datum'
  }, meta_table)
end

--- returns a chained term
-- @tab cls term to chain this operation on
-- @string st reql term name
-- @treturn function @{reql_term}
-- @treturn nil if there is no known term
function meta_table.__index(cls, st)
  if st == 'datum' then return datum end
  local tt = rawget(Term, st)
  if tt == nil then
    return nil
  end

  --- instantiates a chained term
  local function reql_term(...)
    local __optargs, args = (arg_wrappers[st] or no_opts)(cls, ...)

    local inst = setmetatable({tt = tt, st = st}, meta_table)

    --- convert from internal represention to JSON
    function inst.build()
      if st == 'binary' and (not inst.args[1]) then
        return {
          ['$reql_type$'] = 'BINARY',
          data = inst.base64_data
        }
      end
      if st == 'make_obj' then
        local res = {}
        for key, val in pairs(inst.optargs) do
          res[key] = val.build()
        end
        return res
      end
      local _args = {}
      for i, arg in ipairs(inst.args) do
        _args[i] = arg.build()
      end
      local res = {tt, _args}
      if next(inst.optargs) then
        local opts = {}
        for key, val in pairs(inst.optargs) do
          opts[key] = val.build()
        end
        table.insert(res, opts)
      end
      return res
    end

    --- send term to server for evaluation
    -- @tab connection
    -- @tab[opt] options
    -- @func[opt] callback
    function inst.run(connection, options, callback)

      -- Handle run(connection, callback)
      if type(options) == 'function' then
        if callback ~= nil then
          return logger(r, 'Second argument to `run` cannot be a function if a third argument is provided.')
        end
        callback = options
        options = {}
      end
      -- else we suppose that we have run(connection[, options][, callback])

      if connection == nil then
        --[[ TODO
        if r.pool then
          connection = r.pool
        else]]
          return logger(r, 'First argument to `run` must be a connection.')
        --end
      end

      return connection._start(inst, callback, options or {})
    end

    --- get debug represention of query
    -- @tab debug represention of arguments
    -- @tab[opt] debug represention of options
    -- @treturn string
    function inst.compose(_args, _optargs)
      if st == 'make_array' then
        return '{' .. table.concat(_args, ', ') .. '}'
      end
      local function kved(optargs)
        local res = {}
        for k, v in pairs(optargs) do
          table.insert(res, k .. ' = ' .. v)
        end
        return '{' .. table.concat(res, ', ') .. '}'
      end
      if st == 'make_obj' then
        return kved(_optargs)
      end
      if st == 'var' then
        return 'var_' .. _args[1]
      end
      if st == 'binary' and not inst.args[1] then
        return 'r.binary(<data>)'
      end
      if st == 'bracket' then
        return table.concat{_args[1], '(', _args[2], ')'}
      end
      if st == 'func' then
        local res = {}
        for i, v in ipairs(inst.args[1]) do
          res[i] = 'var_' .. v
        end
        return table.concat{
          'function(',
          table.concat(res, ', '),
          ') return ', _args[2], ' end'
        }
      end
      if st == 'do_' then
        local func = table.remove(_args, 1)
        if func then
          table.insert(_args, func)
        end
      end
      local argrepr = {}
      if _args and next(_args) then
        table.insert(argrepr, table.concat(_args, ', '))
      end
      if _optargs and next(_optargs) then
        table.insert(argrepr, kved(_optargs))
      end
      return table.concat{'r.', st, '(', table.concat(argrepr, ', '), ')'}
    end

    if st == 'func' then
      local func = args[1]
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
        table.insert(anon_args, r.var({}, next_var_id))
        next_var_id = next_var_id + 1
      end
      func = func(unpack(anon_args))
      if func == nil then
        return logger(r, 'Anonymous function returned `nil`. Did you forget a `return`?')
      end
      __optargs.arity = nil
      args = {arg_nums, func}
    elseif st == 'binary' then
      local data = args[1]
      if type(data) == 'string' then
        inst.base64_data = b64(r, table.remove(args, 1))
      elseif getmetatable(data) ~= meta_table then
        return logger(r, 'Parameter to `r.binary` must be a string or ReQL query.')
      end
    elseif st == 'funcall' then
      local func = table.remove(args)
      if type(func) == 'function' then
        func = r.func({arity = #args}, func)
      end
      table.insert(args, 1, func)
    elseif st == 'reduce' then
      args[#args] = r.func({arity = 2}, args[#args])
    end

    inst.args = {cls}
    inst.optargs = {}

    for _, a in ipairs(args) do
      table.insert(inst.args, r(a))
    end

    for k, v in pairs(__optargs) do
      inst.optargs[k] = r(v)
    end

    return inst
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

return r
