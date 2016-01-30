local class = require'rethinkdb.class'
local proto = require'rethinkdb.protodef'

--local DATUMTERM, ReQLOp
local ReQLOp

local m = {}
local ast = {}

function m.init(r)
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

    add = function(...) return ast.ADD({}, ...) end,
  and_ = function(...) return ast.AND({}, ...) end,
  append = function(...) return ast.APPEND({}, ...) end,
  april = function(...) return ast.APRIL({}, ...) end,
  args = function(...) return ast.ARGS({}, ...) end,
  asc = function(...) return ast.ASC({}, ...) end,
  august = function(...) return ast.AUGUST({}, ...) end,
  avg = function(...) return ast.AVG({}, ...) end,
  between = function(arg0, arg1, arg2, opts) return ast.BETWEEN(opts, arg0, arg1, arg2) end,
  binary = function(...) return ast.BINARY({}, ...) end,
  index = function(...) return ast.BRACKET({}, ...) end,
  branch = function(...) return ast.BRANCH({}, ...) end,
  ceil = function(...) return ast.CEIL({}, ...) end,
  changes = function(...) return ast.CHANGES({}, ...) end,
  change_at = function(...) return ast.CHANGE_AT({}, ...) end,
  circle = function(...) return ast.CIRCLE(get_opts(...)) end,
  coerce_to = function(...) return ast.COERCE_TO({}, ...) end,
  concat_map = function(...) return ast.CONCAT_MAP({}, ...) end,
  config = function(...) return ast.CONFIG({}, ...) end,
  contains = function(...) return ast.CONTAINS({}, ...) end,
  count = function(...) return ast.COUNT({}, ...) end,
  date = function(...) return ast.DATE({}, ...) end,
  day = function(...) return ast.DAY({}, ...) end,
  day_of_week = function(...) return ast.DAY_OF_WEEK({}, ...) end,
  day_of_year = function(...) return ast.DAY_OF_YEAR({}, ...) end,
  db = function(...) return ast.DB({}, ...) end,
  db_create = function(...) return ast.DB_CREATE({}, ...) end,
  db_drop = function(...) return ast.DB_DROP({}, ...) end,
  db_list = function(...) return ast.DB_LIST({}, ...) end,
  december = function(...) return ast.DECEMBER({}, ...) end,
  default = function(...) return ast.DEFAULT({}, ...) end,
  delete = function(...) return ast.DELETE(get_opts(...)) end,
  delete_at = function(...) return ast.DELETE_AT({}, ...) end,
  desc = function(...) return ast.DESC({}, ...) end,
  difference = function(...) return ast.DIFFERENCE({}, ...) end,
  distance = function(arg0, arg1, opts) return ast.DISTANCE(opts, arg0, arg1) end,
  distinct = function(...) return ast.DISTINCT(get_opts(...)) end,
  div = function(...) return ast.DIV({}, ...) end,
  downcase = function(...) return ast.DOWNCASE({}, ...) end,
  during = function(arg0, arg1, arg2, opts) return ast.DURING(opts, arg0, arg1, arg2) end,
  epoch_time = function(...) return ast.EPOCH_TIME({}, ...) end,
  eq = function(...) return ast.EQ({}, ...) end,
  eq_join = function(...) return ast.EQ_JOIN(get_opts(...)) end,
  error_ = function(...) return ast.ERROR({}, ...) end,
  february = function(...) return ast.FEBRUARY({}, ...) end,
  fill = function(...) return ast.FILL({}, ...) end,
  filter = function(arg0, arg1, opts) return ast.FILTER(opts, arg0, arg1) end,
  floor = function(...) return ast.FLOOR({}, ...) end,
  for_each = function(...) return ast.FOR_EACH({}, ...) end,
  friday = function(...) return ast.FRIDAY({}, ...) end,
  func = function(...) return ast.FUNC({}, ...) end,
  do_ = function(...) return ast.FUNCALL({}, ...) end,
  ge = function(...) return ast.GE({}, ...) end,
  geojson = function(...) return ast.GEOJSON({}, ...) end,
  get = function(...) return ast.GET({}, ...) end,
  get_all = function(...) return ast.GET_ALL(get_opts(...)) end,
  get_field = function(...) return ast.GET_FIELD({}, ...) end,
  get_intersecting = function(...) return ast.GET_INTERSECTING(get_opts(...)) end,
  get_nearest = function(...) return ast.GET_NEAREST(get_opts(...)) end,
  group = function(...) return ast.GROUP(get_opts(...)) end,
  gt = function(...) return ast.GT({}, ...) end,
  has_fields = function(...) return ast.HAS_FIELDS({}, ...) end,
  hours = function(...) return ast.HOURS({}, ...) end,
  http = function(...) return ast.HTTP(get_opts(...)) end,
  includes = function(...) return ast.INCLUDES({}, ...) end,
  index_create = function(...) return ast.INDEX_CREATE(get_opts(...)) end,
  index_drop = function(...) return ast.INDEX_DROP({}, ...) end,
  index_list = function(...) return ast.INDEX_LIST({}, ...) end,
  index_rename = function(...) return ast.INDEX_RENAME(get_opts(...)) end,
  index_status = function(...) return ast.INDEX_STATUS({}, ...) end,
  index_wait = function(...) return ast.INDEX_WAIT({}, ...) end,
  info = function(...) return ast.INFO({}, ...) end,
  inner_join = function(...) return ast.INNER_JOIN({}, ...) end,
  insert = function(arg0, arg1, opts) return ast.INSERT(opts, arg0, arg1) end,
  insert_at = function(...) return ast.INSERT_AT({}, ...) end,
  intersects = function(...) return ast.INTERSECTS({}, ...) end,
  in_timezone = function(...) return ast.IN_TIMEZONE({}, ...) end,
  iso8601 = function(...) return ast.ISO8601(get_opts(...)) end,
  is_empty = function(...) return ast.IS_EMPTY({}, ...) end,
  january = function(...) return ast.JANUARY({}, ...) end,
  js = function(...) return ast.JAVASCRIPT(get_opts(...)) end,
  json = function(...) return ast.JSON({}, ...) end,
  july = function(...) return ast.JULY({}, ...) end,
  june = function(...) return ast.JUNE({}, ...) end,
  keys = function(...) return ast.KEYS({}, ...) end,
  le = function(...) return ast.LE({}, ...) end,
  limit = function(...) return ast.LIMIT({}, ...) end,
  line = function(...) return ast.LINE({}, ...) end,
  literal = function(...) return ast.LITERAL({}, ...) end,
  lt = function(...) return ast.LT({}, ...) end,
  make_array = function(...) return ast.MAKE_ARRAY({}, ...) end,
  make_obj = function(...) return ast.MAKE_OBJ({}, ...) end,
  map = function(...) return ast.MAP({}, ...) end,
  march = function(...) return ast.MARCH({}, ...) end,
  match = function(...) return ast.MATCH({}, ...) end,
  max = function(...) return ast.MAX({}, ...) end,
  maxval = function(...) return ast.MAXVAL({}, ...) end,
  may = function(...) return ast.MAY({}, ...) end,
  merge = function(...) return ast.MERGE({}, ...) end,
  min = function(...) return ast.MIN({}, ...) end,
  minutes = function(...) return ast.MINUTES({}, ...) end,
  minval = function(...) return ast.MINVAL({}, ...) end,
  mod = function(...) return ast.MOD({}, ...) end,
  monday = function(...) return ast.MONDAY({}, ...) end,
  month = function(...) return ast.MONTH({}, ...) end,
  mul = function(...) return ast.MUL({}, ...) end,
  ne = function(...) return ast.NE({}, ...) end,
  not_ = function(...) return ast.NOT({}, ...) end,
  november = function(...) return ast.NOVEMBER({}, ...) end,
  now = function(...) return ast.NOW({}, ...) end,
  nth = function(...) return ast.NTH({}, ...) end,
  object = function(...) return ast.OBJECT({}, ...) end,
  october = function(...) return ast.OCTOBER({}, ...) end,
  offsets_of = function(...) return ast.OFFSETS_OF({}, ...) end,
  or_ = function(...) return ast.OR({}, ...) end,
  order_by = function(...) return ast.ORDER_BY(get_opts(...)) end,
  outer_join = function(...) return ast.OUTER_JOIN({}, ...) end,
  pluck = function(...) return ast.PLUCK({}, ...) end,
  point = function(...) return ast.POINT({}, ...) end,
  polygon = function(...) return ast.POLYGON({}, ...) end,
  polygon_sub = function(...) return ast.POLYGON_SUB({}, ...) end,
  prepend = function(...) return ast.PREPEND({}, ...) end,
  random = function(...) return ast.RANDOM(get_opts(...)) end,
  range = function(...) return ast.RANGE({}, ...) end,
  rebalance = function(...) return ast.REBALANCE({}, ...) end,
  reconfigure = function(...) return ast.RECONFIGURE({}, ...) end,
  reduce = function(...) return ast.REDUCE({}, ...) end,
  replace = function(...) return ast.REPLACE(get_opts(...)) end,
  round = function(...) return ast.ROUND({}, ...) end,
  sample = function(...) return ast.SAMPLE({}, ...) end,
  saturday = function(...) return ast.SATURDAY({}, ...) end,
  seconds = function(...) return ast.SECONDS({}, ...) end,
  september = function(...) return ast.SEPTEMBER({}, ...) end,
  set_difference = function(...) return ast.SET_DIFFERENCE({}, ...) end,
  set_insert = function(...) return ast.SET_INSERT({}, ...) end,
  set_intersection = function(...) return ast.SET_INTERSECTION({}, ...) end,
  set_union = function(...) return ast.SET_UNION({}, ...) end,
  skip = function(...) return ast.SKIP({}, ...) end,
  slice = function(...) return ast.SLICE(get_opts(...)) end,
  splice_at = function(...) return ast.SPLICE_AT({}, ...) end,
  split = function(...) return ast.SPLIT({}, ...) end,
  status = function(...) return ast.STATUS({}, ...) end,
  sub = function(...) return ast.SUB({}, ...) end,
  sum = function(...) return ast.SUM({}, ...) end,
  sunday = function(...) return ast.SUNDAY({}, ...) end,
  sync = function(...) return ast.SYNC({}, ...) end,
  table = function(...) return ast.TABLE(get_opts(...)) end,
  table_create = function(...) return ast.TABLE_CREATE(get_opts(...)) end,
  table_drop = function(...) return ast.TABLE_DROP({}, ...) end,
  table_list = function(...) return ast.TABLE_LIST({}, ...) end,
  thursday = function(...) return ast.THURSDAY({}, ...) end,
  time = function(...) return ast.TIME({}, ...) end,
  timezone = function(...) return ast.TIMEZONE({}, ...) end,
  time_of_day = function(...) return ast.TIME_OF_DAY({}, ...) end,
  to_epoch_time = function(...) return ast.TO_EPOCH_TIME({}, ...) end,
  to_geojson = function(...) return ast.TO_GEOJSON({}, ...) end,
  to_iso8601 = function(...) return ast.TO_ISO8601({}, ...) end,
  to_json_string = function(...) return ast.TO_JSON_STRING({}, ...) end,
  tuesday = function(...) return ast.TUESDAY({}, ...) end,
  type_of = function(...) return ast.TYPE_OF({}, ...) end,
  ungroup = function(...) return ast.UNGROUP({}, ...) end,
  union = function(...) return ast.UNION({}, ...) end,
  upcase = function(...) return ast.UPCASE({}, ...) end,
  update = function(arg0, arg1, opts) return ast.UPDATE(opts, arg0, arg1) end,
  uuid = function(...) return ast.UUID({}, ...) end,
  values = function(...) return ast.VALUES({}, ...) end,
  var = function(...) return ast.VAR({}, ...) end,
  wait = function(...) return ast.WAIT({}, ...) end,
  wednesday = function(...) return ast.WEDNESDAY({}, ...) end,
  without = function(...) return ast.WITHOUT({}, ...) end,
  with_fields = function(...) return ast.WITH_FIELDS({}, ...) end,
  year = function(...) return ast.YEAR({}, ...) end,
  zip = function(...) return ast.ZIP({}, ...) end
  }

  class_methods = {
    __init = function(self, optargs, ...)
      local args = {...}
      optargs = optargs or {}
      if self.tt == proto.Term.FUNC then
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
          table.insert(anon_args, ast.VAR({}, ReQLOp.next_var_id))
          ReQLOp.next_var_id = ReQLOp.next_var_id + 1
        end
        func = func(unpack(anon_args))
        if func == nil then
          return error('Anonymous function returned `nil`. Did you forget a `return`?')
        end
        optargs.arity = nil
        args = {arg_nums, func}
      elseif self.tt == proto.Term.BINARY then
        local data = args[1]
        if r.is_instance(data, 'ReQLOp') then
        elseif type(data) == 'string' then
          self.base64_data = r._b64(table.remove(args, 1))
        else
          return error('Parameter to `r.binary` must be a string or ReQL query.')
        end
      elseif self.tt == proto.Term.FUNCALL then
        local func = table.remove(args)
        if type(func) == 'function' then
          func = ast.FUNC({arity = #args}, func)
        end
        table.insert(args, 1, func)
      elseif self.tt == proto.Term.REDUCE then
        args[#args] = ast.FUNC({arity = 2}, args[#args])
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
      if self.tt == proto.Term.BINARY and (not self.args[1]) then
        return {
          ['$reql_type$'] = 'BINARY',
          data = self.base64_data
        }
      end
      if self.tt == proto.Term.MAKE_OBJ then
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
      if self.tt == proto.Term.MAKE_ARRAY then
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
      if self.tt == proto.Term.MAKE_OBJ then
        return kved(optargs)
      end
      if self.tt == proto.Term.VAR then
        return {'var_' .. args[1]}
      end
      if self.tt == proto.Term.BINARY and not self.args[1] then
        return 'r.binary(<data>)'
      end
      if self.tt == proto.Term.BRACKET then
        return {args[1], '(', args[2], ')'}
      end
      if self.tt == proto.Term.FUNC then
        return {
          'function(',
          intsp((function()
            local _accum_0 = {}
            for i, v in ipairs(self.args[1]) do
              _accum_0[i] = 'var_' .. v
            end
            return _accum_0
          end)()),
          ') return ', args[2], ' end'
        }
      end
      if self.tt == proto.Term.FUNCALL then
        local func = table.remove(args, 1)
        if func then
          table.insert(args, func)
        end
      end
      if not self.args then
        return {type(self)}
      end
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
      return {'r.' .. self.st .. '(', argrepr, ')'}
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
      return ast.BRACKET({}, ...)
    end,
    __add = function(...)
      return ast.ADD({}, ...)
    end,
    __mul = function(...)
      return ast.MUL({}, ...)
    end,
    __mod = function(...)
      return ast.MOD({}, ...)
    end,
    __sub = function(...)
      return ast.SUB({}, ...)
    end,
    __div = function(...)
      return ast.DIV({}, ...)
    end
  }

  function build_ast(name, base)
    for k, v in pairs(meta) do
      base[k] = v
    end
    return class(name, ReQLOp, base)
  end
  ast = {
    DATUMTERM = build_ast(
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
    ADD = build_ast('ADD', {tt = 24, st = 'add'}),
  AND = build_ast('AND', {tt = 67, st = 'and_'}),
  APPEND = build_ast('APPEND', {tt = 29, st = 'append'}),
  APRIL = build_ast('APRIL', {tt = 117, st = 'april'}),
  ARGS = build_ast('ARGS', {tt = 154, st = 'args'}),
  ASC = build_ast('ASC', {tt = 73, st = 'asc'}),
  AUGUST = build_ast('AUGUST', {tt = 121, st = 'august'}),
  AVG = build_ast('AVG', {tt = 146, st = 'avg'}),
  BETWEEN = build_ast('BETWEEN', {tt = 182, st = 'between'}),
  BINARY = build_ast('BINARY', {tt = 155, st = 'binary'}),
  BRACKET = build_ast('BRACKET', {tt = 170, st = 'index'}),
  BRANCH = build_ast('BRANCH', {tt = 65, st = 'branch'}),
  CEIL = build_ast('CEIL', {tt = 184, st = 'ceil'}),
  CHANGES = build_ast('CHANGES', {tt = 152, st = 'changes'}),
  CHANGE_AT = build_ast('CHANGE_AT', {tt = 84, st = 'change_at'}),
  CIRCLE = build_ast('CIRCLE', {tt = 165, st = 'circle'}),
  COERCE_TO = build_ast('COERCE_TO', {tt = 51, st = 'coerce_to'}),
  CONCAT_MAP = build_ast('CONCAT_MAP', {tt = 40, st = 'concat_map'}),
  CONFIG = build_ast('CONFIG', {tt = 174, st = 'config'}),
  CONTAINS = build_ast('CONTAINS', {tt = 93, st = 'contains'}),
  COUNT = build_ast('COUNT', {tt = 43, st = 'count'}),
  DATE = build_ast('DATE', {tt = 106, st = 'date'}),
  DAY = build_ast('DAY', {tt = 130, st = 'day'}),
  DAY_OF_WEEK = build_ast('DAY_OF_WEEK', {tt = 131, st = 'day_of_week'}),
  DAY_OF_YEAR = build_ast('DAY_OF_YEAR', {tt = 132, st = 'day_of_year'}),
  DB = build_ast('DB', {tt = 14, st = 'db'}),
  DB_CREATE = build_ast('DB_CREATE', {tt = 57, st = 'db_create'}),
  DB_DROP = build_ast('DB_DROP', {tt = 58, st = 'db_drop'}),
  DB_LIST = build_ast('DB_LIST', {tt = 59, st = 'db_list'}),
  DECEMBER = build_ast('DECEMBER', {tt = 125, st = 'december'}),
  DEFAULT = build_ast('DEFAULT', {tt = 92, st = 'default'}),
  DELETE = build_ast('DELETE', {tt = 54, st = 'delete'}),
  DELETE_AT = build_ast('DELETE_AT', {tt = 83, st = 'delete_at'}),
  DESC = build_ast('DESC', {tt = 74, st = 'desc'}),
  DIFFERENCE = build_ast('DIFFERENCE', {tt = 95, st = 'difference'}),
  DISTANCE = build_ast('DISTANCE', {tt = 162, st = 'distance'}),
  DISTINCT = build_ast('DISTINCT', {tt = 42, st = 'distinct'}),
  DIV = build_ast('DIV', {tt = 27, st = 'div'}),
  DOWNCASE = build_ast('DOWNCASE', {tt = 142, st = 'downcase'}),
  DURING = build_ast('DURING', {tt = 105, st = 'during'}),
  EPOCH_TIME = build_ast('EPOCH_TIME', {tt = 101, st = 'epoch_time'}),
  EQ = build_ast('EQ', {tt = 17, st = 'eq'}),
  EQ_JOIN = build_ast('EQ_JOIN', {tt = 50, st = 'eq_join'}),
  ERROR = build_ast('ERROR', {tt = 12, st = 'error_'}),
  FEBRUARY = build_ast('FEBRUARY', {tt = 115, st = 'february'}),
  FILL = build_ast('FILL', {tt = 167, st = 'fill'}),
  FILTER = build_ast('FILTER', {tt = 39, st = 'filter'}),
  FLOOR = build_ast('FLOOR', {tt = 183, st = 'floor'}),
  FOR_EACH = build_ast('FOR_EACH', {tt = 68, st = 'for_each'}),
  FRIDAY = build_ast('FRIDAY', {tt = 111, st = 'friday'}),
  FUNC = build_ast('FUNC', {tt = 69, st = 'func'}),
  FUNCALL = build_ast('FUNCALL', {tt = 64, st = 'do_'}),
  GE = build_ast('GE', {tt = 22, st = 'ge'}),
  GEOJSON = build_ast('GEOJSON', {tt = 157, st = 'geojson'}),
  GET = build_ast('GET', {tt = 16, st = 'get'}),
  GET_ALL = build_ast('GET_ALL', {tt = 78, st = 'get_all'}),
  GET_FIELD = build_ast('GET_FIELD', {tt = 31, st = 'get_field'}),
  GET_INTERSECTING = build_ast('GET_INTERSECTING', {tt = 166, st = 'get_intersecting'}),
  GET_NEAREST = build_ast('GET_NEAREST', {tt = 168, st = 'get_nearest'}),
  GROUP = build_ast('GROUP', {tt = 144, st = 'group'}),
  GT = build_ast('GT', {tt = 21, st = 'gt'}),
  HAS_FIELDS = build_ast('HAS_FIELDS', {tt = 32, st = 'has_fields'}),
  HOURS = build_ast('HOURS', {tt = 133, st = 'hours'}),
  HTTP = build_ast('HTTP', {tt = 153, st = 'http'}),
  INCLUDES = build_ast('INCLUDES', {tt = 164, st = 'includes'}),
  INDEX_CREATE = build_ast('INDEX_CREATE', {tt = 75, st = 'index_create'}),
  INDEX_DROP = build_ast('INDEX_DROP', {tt = 76, st = 'index_drop'}),
  INDEX_LIST = build_ast('INDEX_LIST', {tt = 77, st = 'index_list'}),
  INDEX_RENAME = build_ast('INDEX_RENAME', {tt = 156, st = 'index_rename'}),
  INDEX_STATUS = build_ast('INDEX_STATUS', {tt = 139, st = 'index_status'}),
  INDEX_WAIT = build_ast('INDEX_WAIT', {tt = 140, st = 'index_wait'}),
  INFO = build_ast('INFO', {tt = 79, st = 'info'}),
  INNER_JOIN = build_ast('INNER_JOIN', {tt = 48, st = 'inner_join'}),
  INSERT = build_ast('INSERT', {tt = 56, st = 'insert'}),
  INSERT_AT = build_ast('INSERT_AT', {tt = 82, st = 'insert_at'}),
  INTERSECTS = build_ast('INTERSECTS', {tt = 163, st = 'intersects'}),
  IN_TIMEZONE = build_ast('IN_TIMEZONE', {tt = 104, st = 'in_timezone'}),
  ISO8601 = build_ast('ISO8601', {tt = 99, st = 'iso8601'}),
  IS_EMPTY = build_ast('IS_EMPTY', {tt = 86, st = 'is_empty'}),
  JANUARY = build_ast('JANUARY', {tt = 114, st = 'january'}),
  JAVASCRIPT = build_ast('JAVASCRIPT', {tt = 11, st = 'js'}),
  JSON = build_ast('JSON', {tt = 98, st = 'json'}),
  JULY = build_ast('JULY', {tt = 120, st = 'july'}),
  JUNE = build_ast('JUNE', {tt = 119, st = 'june'}),
  KEYS = build_ast('KEYS', {tt = 94, st = 'keys'}),
  LE = build_ast('LE', {tt = 20, st = 'le'}),
  LIMIT = build_ast('LIMIT', {tt = 71, st = 'limit'}),
  LINE = build_ast('LINE', {tt = 160, st = 'line'}),
  LITERAL = build_ast('LITERAL', {tt = 137, st = 'literal'}),
  LT = build_ast('LT', {tt = 19, st = 'lt'}),
  MAKE_ARRAY = build_ast('MAKE_ARRAY', {tt = 2, st = 'make_array'}),
  MAKE_OBJ = build_ast('MAKE_OBJ', {tt = 3, st = 'make_obj'}),
  MAP = build_ast('MAP', {tt = 38, st = 'map'}),
  MARCH = build_ast('MARCH', {tt = 116, st = 'march'}),
  MATCH = build_ast('MATCH', {tt = 97, st = 'match'}),
  MAX = build_ast('MAX', {tt = 148, st = 'max'}),
  MAXVAL = build_ast('MAXVAL', {tt = 181, st = 'maxval'}),
  MAY = build_ast('MAY', {tt = 118, st = 'may'}),
  MERGE = build_ast('MERGE', {tt = 35, st = 'merge'}),
  MIN = build_ast('MIN', {tt = 147, st = 'min'}),
  MINUTES = build_ast('MINUTES', {tt = 134, st = 'minutes'}),
  MINVAL = build_ast('MINVAL', {tt = 180, st = 'minval'}),
  MOD = build_ast('MOD', {tt = 28, st = 'mod'}),
  MONDAY = build_ast('MONDAY', {tt = 107, st = 'monday'}),
  MONTH = build_ast('MONTH', {tt = 129, st = 'month'}),
  MUL = build_ast('MUL', {tt = 26, st = 'mul'}),
  NE = build_ast('NE', {tt = 18, st = 'ne'}),
  NOT = build_ast('NOT', {tt = 23, st = 'not_'}),
  NOVEMBER = build_ast('NOVEMBER', {tt = 124, st = 'november'}),
  NOW = build_ast('NOW', {tt = 103, st = 'now'}),
  NTH = build_ast('NTH', {tt = 45, st = 'nth'}),
  OBJECT = build_ast('OBJECT', {tt = 143, st = 'object'}),
  OCTOBER = build_ast('OCTOBER', {tt = 123, st = 'october'}),
  OFFSETS_OF = build_ast('OFFSETS_OF', {tt = 87, st = 'offsets_of'}),
  OR = build_ast('OR', {tt = 66, st = 'or_'}),
  ORDER_BY = build_ast('ORDER_BY', {tt = 41, st = 'order_by'}),
  OUTER_JOIN = build_ast('OUTER_JOIN', {tt = 49, st = 'outer_join'}),
  PLUCK = build_ast('PLUCK', {tt = 33, st = 'pluck'}),
  POINT = build_ast('POINT', {tt = 159, st = 'point'}),
  POLYGON = build_ast('POLYGON', {tt = 161, st = 'polygon'}),
  POLYGON_SUB = build_ast('POLYGON_SUB', {tt = 171, st = 'polygon_sub'}),
  PREPEND = build_ast('PREPEND', {tt = 80, st = 'prepend'}),
  RANDOM = build_ast('RANDOM', {tt = 151, st = 'random'}),
  RANGE = build_ast('RANGE', {tt = 173, st = 'range'}),
  REBALANCE = build_ast('REBALANCE', {tt = 179, st = 'rebalance'}),
  RECONFIGURE = build_ast('RECONFIGURE', {tt = 176, st = 'reconfigure'}),
  REDUCE = build_ast('REDUCE', {tt = 37, st = 'reduce'}),
  REPLACE = build_ast('REPLACE', {tt = 55, st = 'replace'}),
  ROUND = build_ast('ROUND', {tt = 185, st = 'round'}),
  SAMPLE = build_ast('SAMPLE', {tt = 81, st = 'sample'}),
  SATURDAY = build_ast('SATURDAY', {tt = 112, st = 'saturday'}),
  SECONDS = build_ast('SECONDS', {tt = 135, st = 'seconds'}),
  SEPTEMBER = build_ast('SEPTEMBER', {tt = 122, st = 'september'}),
  SET_DIFFERENCE = build_ast('SET_DIFFERENCE', {tt = 91, st = 'set_difference'}),
  SET_INSERT = build_ast('SET_INSERT', {tt = 88, st = 'set_insert'}),
  SET_INTERSECTION = build_ast('SET_INTERSECTION', {tt = 89, st = 'set_intersection'}),
  SET_UNION = build_ast('SET_UNION', {tt = 90, st = 'set_union'}),
  SKIP = build_ast('SKIP', {tt = 70, st = 'skip'}),
  SLICE = build_ast('SLICE', {tt = 30, st = 'slice'}),
  SPLICE_AT = build_ast('SPLICE_AT', {tt = 85, st = 'splice_at'}),
  SPLIT = build_ast('SPLIT', {tt = 149, st = 'split'}),
  STATUS = build_ast('STATUS', {tt = 175, st = 'status'}),
  SUB = build_ast('SUB', {tt = 25, st = 'sub'}),
  SUM = build_ast('SUM', {tt = 145, st = 'sum'}),
  SUNDAY = build_ast('SUNDAY', {tt = 113, st = 'sunday'}),
  SYNC = build_ast('SYNC', {tt = 138, st = 'sync'}),
  TABLE = build_ast('TABLE', {tt = 15, st = 'table'}),
  TABLE_CREATE = build_ast('TABLE_CREATE', {tt = 60, st = 'table_create'}),
  TABLE_DROP = build_ast('TABLE_DROP', {tt = 61, st = 'table_drop'}),
  TABLE_LIST = build_ast('TABLE_LIST', {tt = 62, st = 'table_list'}),
  THURSDAY = build_ast('THURSDAY', {tt = 110, st = 'thursday'}),
  TIME = build_ast('TIME', {tt = 136, st = 'time'}),
  TIMEZONE = build_ast('TIMEZONE', {tt = 127, st = 'timezone'}),
  TIME_OF_DAY = build_ast('TIME_OF_DAY', {tt = 126, st = 'time_of_day'}),
  TO_EPOCH_TIME = build_ast('TO_EPOCH_TIME', {tt = 102, st = 'to_epoch_time'}),
  TO_GEOJSON = build_ast('TO_GEOJSON', {tt = 158, st = 'to_geojson'}),
  TO_ISO8601 = build_ast('TO_ISO8601', {tt = 100, st = 'to_iso8601'}),
  TO_JSON_STRING = build_ast('TO_JSON_STRING', {tt = 172, st = 'to_json_string'}),
  TUESDAY = build_ast('TUESDAY', {tt = 108, st = 'tuesday'}),
  TYPE_OF = build_ast('TYPE_OF', {tt = 52, st = 'type_of'}),
  UNGROUP = build_ast('UNGROUP', {tt = 150, st = 'ungroup'}),
  UNION = build_ast('UNION', {tt = 44, st = 'union'}),
  UPCASE = build_ast('UPCASE', {tt = 141, st = 'upcase'}),
  UPDATE = build_ast('UPDATE', {tt = 53, st = 'update'}),
  UUID = build_ast('UUID', {tt = 169, st = 'uuid'}),
  VALUES = build_ast('VALUES', {tt = 186, st = 'values'}),
  VAR = build_ast('VAR', {tt = 10, st = 'var'}),
  WAIT = build_ast('WAIT', {tt = 177, st = 'wait'}),
  WEDNESDAY = build_ast('WEDNESDAY', {tt = 109, st = 'wednesday'}),
  WITHOUT = build_ast('WITHOUT', {tt = 34, st = 'without'}),
  WITH_FIELDS = build_ast('WITH_FIELDS', {tt = 96, st = 'with_fields'}),
  YEAR = build_ast('YEAR', {tt = 128, st = 'year'}),
  ZIP = build_ast('ZIP', {tt = 72, st = 'zip'}),
  }
  return ast

end
return m
