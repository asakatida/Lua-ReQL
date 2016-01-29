local class = require'rethinkdb.class'

local DATUMTERM, ReQLOp
--[[AstNames]]

function get_opts(...)
  local args = {...}
  local opt = {}
  local pos_opt = args[#args]
  if (type(pos_opt) == 'table') and (not r.is_instance(pos_opt, 'ReQLOp')) then
    opt = pos_opt
    args[#args] = nil
  end
  return opt, unpack(args)
end

ast_methods = {
  run = function(self, connection, options, callback)
    -- Valid syntaxes are
    -- connection
    -- connection, callback
    -- connection, options, callback
    -- connection, nil, callback

    -- Handle run(connection, callback)
    if type(options) == 'function' then
      if callback then
        return error('Second argument to `run` cannot be a function if a third argument is provided.')
      end
      callback = options
      options = {}
    end
    -- else we suppose that we have run(connection[, options][, callback])

    if not r.is_instance(connection, 'Connection', 'Pool') then
      if r._pool then
        connection = r._pool
      else
        if callback then
          return callback(ReQLDriverError('First argument to `run` must be a connection.'))
        end
        return error('First argument to `run` must be a connection.')
      end
    end

    return connection:_start(self, callback, options or {})
  end,

  --[[AstMethods]]
}

class_methods = {
  __init = function(self, optargs, ...)
    local args = {...}
    optargs = optargs or {}
    if self.tt == --[[Term.FUNC]] then
      local func = args[1]
      local anon_args = {}
      local arg_nums = {}
      if debug.getinfo then
        local func_info = debug.getinfo(func)
        if func_info.what == 'Lua' and func_info.nparams then
          optargs.arity = func_info.nparams
        end
      end
      for i=1, optargs.arity or 1 do
        table.insert(arg_nums, ReQLOp.next_var_id)
        table.insert(anon_args, VAR({}, ReQLOp.next_var_id))
        ReQLOp.next_var_id = ReQLOp.next_var_id + 1
      end
      func = func(unpack(anon_args))
      if func == nil then
        return error('Anonymous function returned `nil`. Did you forget a `return`?')
      end
      optargs.arity = nil
      args = {arg_nums, func}
    elseif self.tt == --[[Term.BINARY]] then
      local data = args[1]
      if r.is_instance(data, 'ReQLOp') then
      elseif type(data) == 'string' then
        self.base64_data = r._b64(table.remove(args, 1))
      else
        return error('Parameter to `r.binary` must be a string or ReQL query.')
      end
    elseif self.tt == --[[Term.FUNCALL]] then
      local func = table.remove(args)
      if type(func) == 'function' then
        func = FUNC({arity = #args}, func)
      end
      table.insert(args, 1, func)
    elseif self.tt == --[[Term.REDUCE]] then
      args[#args] = FUNC({arity = 2}, args[#args])
    end
    self.args = {}
    self.optargs = {}
    for i, a in ipairs(args) do
      self.args[i] = r(a)
    end
    for k, v in pairs(optargs) do
      self.optargs[k] = r(v)
    end
  end,
  build = function(self)
    if self.tt == --[[Term.BINARY]] and (not self.args[1]) then
      return {
        ['$reql_type$'] = 'BINARY',
        data = self.base64_data
      }
    end
    if self.tt == --[[Term.MAKE_OBJ]] then
      local res = {}
      for key, val in pairs(self.optargs) do
        res[key] = val:build()
      end
      return res
    end
    local args = {}
    for i, arg in ipairs(self.args) do
      args[i] = arg:build()
    end
    res = {self.tt, args}
    if next(self.optargs) then
      local opts = {}
      for key, val in pairs(self.optargs) do
        opts[key] = val:build()
      end
      table.insert(res, opts)
    end
    return res
  end,
  compose = function(self, args, optargs)
    intsp = function(seq)
      local res = {}
      local sep = ''
      for _, v in ipairs(seq) do
        table.insert(res, {sep, v})
        sep = ', '
      end
      return res
    end
    if self.tt == --[[Term.MAKE_ARRAY]] then
      return {
        '{',
        intsp(args),
        '}'
      }
    end
    kved = function(optargs)
      local res = {'{'}
      local sep = ''
      for k, v in pairs(optargs) do
        table.insert(res, {sep, k, ': ', v})
        sep = ', '
      end
      table.insert(res, '}')
      return res
    end
    if self.tt == --[[Term.MAKE_OBJ]] then
      return kved(optargs)
    end
    if self.tt == --[[Term.VAR]] then
      return {'var_' .. args[1]}
    end
    if self.tt == --[[Term.BINARY]] and not self.args[1] then
      return 'r.binary(<data>)'
    end
    if self.tt == --[[Term.BRACKET]] then
      return {
        args[1],
        '(',
        args[2],
        ')'
      }
    end
    if self.tt == --[[Term.FUNC]] then
      return {
        'function(',
        intsp((function()
          local _accum_0 = {}
          for i, v in ipairs(self.args[1]) do
            _accum_0[i] = 'var_' .. v
          end
          return _accum_0
        end)()),
        ') return ',
        args[2],
        ' end'
      }
    end
    if self.tt == --[[Term.FUNCALL]] then
      local func = table.remove(args, 1)
      if func then
        table.insert(args, func)
      end
    end
    if not self.args then
      return {
        type(self)
      }
    end
    intspallargs = function(args, optargs)
      local argrepr = {}
      if args and next(args) then
        table.insert(argrepr, intsp(args))
      end
      if optargs and next(optargs) then
        if next(argrepr) then
          table.insert(argrepr, ', ')
        end
        table.insert(argrepr, kved(optargs))
      end
      return argrepr
    end
    return {
      'r.' .. self.st .. '(',
      intspallargs(args, optargs),
      ')'
    }
  end,
  next_var_id = 0,
}

for name, meth in pairs(ast_methods) do
  class_methods[name] = meth
  r[name] = meth
end

-- AST classes

ReQLOp = class('ReQLOp', class_methods)

local meta = {
  __call = function(...)
    return BRACKET({}, ...)
  end,
  __add = function(...)
    return ADD({}, ...)
  end,
  __mul = function(...)
    return MUL({}, ...)
  end,
  __mod = function(...)
    return MOD({}, ...)
  end,
  __sub = function(...)
    return SUB({}, ...)
  end,
  __div = function(...)
    return DIV({}, ...)
  end
}

function ast(name, base)
  for k, v in pairs(meta) do
    base[k] = v
  end
  return class(name, ReQLOp, base)
end

return {
  DATUMTERM = ast(
    'DATUMTERM',
    {
      __init = function(self, val)
        if type(val) == 'number' then
          if math.abs(val) == math.huge or val ~= val then
            return error('Illegal non-finite number `' .. val .. '`.')
          end
        end
        self.data = val
      end,
      args = {},
      optargs = {},
      compose = function(self)
        if self.data == nil then
          return 'nil'
        end
        return r._encode(self.data)
      end,
      build = function(self)
        if self.data == nil then
          if not r.json_parser then
            r._lib_json = require('json')
            r.json_parser = r._lib_json
          end
          if r.json_parser.null then
            return r.json_parser.null
          end
          if r.json_parser.util then
            return r.json_parser.util.null
          end
        end
        return self.data
      end
    }
  ),
--[[AstClasses]]
}
