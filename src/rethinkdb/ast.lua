local errors = require'rethinkdb.errors'
local proto = require'rethinkdb.protodef'
local unpack = require'rethinkdb.unpack'

local m = {}

function m.init(_r)
  local meta_table = {}

  local function no_opts(...)
    return {}, ...
  end

  local function get_opts(...)
    local args = {...}
    local opt = {}
    local pos_opt = args[#args]
    if (type(pos_opt) == 'table') and (getmetatable(pos_opt) ~= meta_table) then
      opt = pos_opt
      args[#args] = nil
    end
    return opt, unpack(args)
  end

  local function arity_1(arg0, opts)
    return opts, arg0
  end

  local function arity_2(arg0, arg1, opts)
    return opts, arg0, arg1
  end

  local function arity_3(arg0, arg1, arg2, opts)
    return opts, arg0, arg1, arg2
  end

  local next_var_id = 0

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

  local function wrap_args(term_name, init)
    local wrap = arg_wrappers[term_name] or no_opts
    local function new_init(...)
      return init(wrap(...))
    end
    return new_init
  end

  local function datum(val)
    if type(val) == 'number' then
      if math.abs(val) == math.huge or val ~= val then
        return error('Illegal non-finite number `' .. val .. '`.')
      end
    end
    return setmetatable({
      __name = 'ReQLOp',
      args = {},
      build = function()
        if val == nil then
          return _r.encode()
        end
        return val
      end,
      compose = function()
        if val == nil then
          return 'nil'
        end
        return _r.encode(val)
      end,
      optargs = {},
      tt = proto.Term.datum,
      st = 'datum'
    }, meta_table)
  end

  function meta_table.__index(cls, st)
    if st == 'datum' then return datum end
    local tt = rawget(proto.Term, st)
    if tt == nil then
      return nil
    end
    return wrap_args(function(__optargs, ...)
      local term = setmetatable({__name = 'ReQLOp', tt = tt, st = st}, meta_table)
      function term.build()
        if st == 'binary' and (not term.args[1]) then
          return {
            ['$reql_type$'] = 'BINARY',
            data = term.base64_data
          }
        end
        if st == 'make_obj' then
          local res = {}
          for key, val in pairs(term.optargs) do
            res[key] = val:build()
          end
          return res
        end
        local args = {}
        for i, arg in ipairs(term.args) do
          args[i] = arg:build()
        end
        local res = {tt, args}
        if next(term.optargs) then
          local opts = {}
          for key, val in pairs(term.optargs) do
            opts[key] = val:build()
          end
          table.insert(res, opts)
        end
        return res
      end
      function term.run(connection, options, callback)
        -- Valid syntaxes are
        -- connection
        -- connection, callback
        -- connection, options, callback
        -- connection, nil, callback

        -- Handle run(connection, callback)
        if type(options) == 'function' then
          if callback ~= nil then
            return error('Second argument to `run` cannot be a function if a third argument is provided.')
          end
          callback = options
          options = {}
        end
        -- else we suppose that we have run(connection[, options][, callback])

        if connection == nil then
          if _r.pool then
            connection = _r.pool
          else
            if callback then
              return callback(errors.ReQLDriverError('First argument to `run` must be a connection.'))
            end
            return error('First argument to `run` must be a connection.')
          end
        end

        return connection._start(term, callback, options or {})
      end

      function term.compose(args, _optargs)
        local intsp = function(seq)
          local res = {}
          local sep = ''
          for _, v in ipairs(seq) do
            table.insert(res, {sep, v})
            sep = ', '
          end
          return res
        end
        if st == 'make_array' then
          return {
            '{',
            intsp(args),
            '}'
          }
        end
        local kved = function(optargs)
          local res = {'{'}
          local sep = ''
          for k, v in pairs(optargs) do
            table.insert(res, {sep, k, ': ', v})
            sep = ', '
          end
          table.insert(res, '}')
          return res
        end
        if st == 'make_obj' then
          return kved(_optargs)
        end
        if st == 'var' then
          return {'var_' .. args[1]}
        end
        if st == 'binary' and not term.args[1] then
          return 'r.binary(<data>)'
        end
        if st == 'bracket' then
          return {args[1], '(', args[2], ')'}
        end
        if st == 'func' then
          return {
            'function(',
            intsp((function()
              local _accum_0 = {}
              for i, v in ipairs(term.args[1]) do
                _accum_0[i] = 'var_' .. v
              end
              return _accum_0
            end)()),
            ') return ', args[2], ' end'
          }
        end
        if st == 'do_' then
          local func = table.remove(args, 1)
          if func then
            table.insert(args, func)
          end
        end
        if not term.args then
          return {'r.' .. st .. '()'}
        end
        local argrepr = {}
        if args and next(args) then
          table.insert(argrepr, intsp(args))
        end
        if _optargs and next(_optargs) then
          if next(argrepr) then
            table.insert(argrepr, ', ')
          end
          table.insert(argrepr, kved(_optargs))
        end
        return {'r.' .. st .. '(', argrepr, ')'}
      end

      local args = {...}
      __optargs = __optargs or {}
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
          table.insert(anon_args, _r.var({}, next_var_id))
          next_var_id = next_var_id + 1
        end
        func = func(unpack(anon_args))
        if func == nil then
          return error('Anonymous function returned `nil`. Did you forget a `return`?')
        end
        __optargs.arity = nil
        args = {arg_nums, func}
      elseif st == 'binary' then
        local data = args[1]
        if type(data) == 'string' then
          term.base64_data = _r.b64(table.remove(args, 1))
        elseif getmetatable(data) ~= meta_table then
          return error('Parameter to `r.binary` must be a string or ReQL query.')
        end
      elseif st == 'funcall' then
        local func = table.remove(args)
        if type(func) == 'function' then
          func = _r.func({arity = #args}, func)
        end
        table.insert(args, 1, func)
      elseif st == 'reduce' then
        args[#args] = _r.func({arity = 2}, args[#args])
      end
      term.args = {cls}
      term.optargs = {}
      for _, a in ipairs(args) do
        table.insert(term.args, _r(a))
      end
      for k, v in pairs(__optargs) do
        term.optargs[k] = _r(v)
      end
    end)
  end

  function meta_table.__call(...)
    return _r.bracket(...)
  end

  function meta_table.__add(...)
    return _r.add(...)
  end

  function meta_table.__mul(...)
    return _r.mul(...)
  end

  function meta_table.__mod(...)
    return _r.mod(...)
  end

  function meta_table.__sub(...)
    return _r.sub(...)
  end

  function meta_table.__div(...)
    return _r.div(...)
  end

  local function expr(r, val, nesting_depth)
    if nesting_depth == nil then
      nesting_depth = 20
    end
    if type(nesting_depth) ~= 'number' then
      return _r.logger('Second argument to `r(val, nesting_depth)` must be a number.')
    end
    if nesting_depth <= 0 then
      return _r.logger('Nesting depth limit exceeded')
    end
    if getmetatable(val) == meta_table then
      return val
    end
    if type(val) == 'function' then
      return _r.func(val)
    end
    if type(val) == 'table' then
      local array = true
      for k, v in pairs(val) do
        if type(k) ~= 'number' then array = false end
        val[k] = r(v, nesting_depth - 1)
      end
      if array then
        return _r.make_array(unpack(val))
      end
      return _r.make_obj(val)
    end
    if type(val) == 'userdata' then
      val = pcall(tostring, val)
      _r.logger('Found userdata inserting "' .. val .. '" into query')
      return _r.datum(val)
    end
    if type(val) == 'thread' then
      val = pcall(tostring, val)
      _r.logger('Cannot insert thread object into query ' .. val)
      return nil
    end
    return _r.datum(val)
  end

  return meta_table, expr
end
return m
