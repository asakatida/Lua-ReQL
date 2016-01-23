local class = require'rethinkdb.class'

local DATUMTERM, ReQLOp
local ADD, AND, APPEND, APRIL, ARGS, ASC, AUGUST, AVG, BETWEEN, BINARY
local BRACKET, BRANCH, CEIL, CHANGES, CHANGE_AT, CIRCLE, COERCE_TO, CONCAT_MAP
local CONFIG, CONTAINS, COUNT, DATE, DAY, DAY_OF_WEEK, DAY_OF_YEAR, DB
local DB_CREATE, DB_DROP, DB_LIST, DECEMBER, DEFAULT, DELETE, DELETE_AT, DESC
local DIFFERENCE, DISTANCE, DISTINCT, DIV, DOWNCASE, DURING, EPOCH_TIME, EQ
local EQ_JOIN, ERROR, FEBRUARY, FILL, FILTER, FLOOR, FOR_EACH, FRIDAY, FUNC
local FUNCALL, GE, GEOJSON, GET, GET_ALL, GET_FIELD, GET_INTERSECTING
local GET_NEAREST, GROUP, GT, HAS_FIELDS, HOURS, HTTP, INCLUDES, INDEX_CREATE
local INDEX_DROP, INDEX_LIST, INDEX_RENAME, INDEX_STATUS, INDEX_WAIT, INFO
local INNER_JOIN, INSERT, INSERT_AT, INTERSECTS, IN_TIMEZONE, ISO8601
local IS_EMPTY, JANUARY, JAVASCRIPT, JSON, JULY, JUNE, KEYS, LE, LIMIT, LINE
local LITERAL, LT, MAKE_ARRAY, MAKE_OBJ, MAP, MARCH, MATCH, MAX, MAXVAL, MAY
local MERGE, MIN, MINUTES, MINVAL, MOD, MONDAY, MONTH, MUL, NE, NOT, NOVEMBER
local NOW, NTH, OBJECT, OCTOBER, OFFSETS_OF, OR, ORDER_BY, OUTER_JOIN, PLUCK
local POINT, POLYGON, POLYGON_SUB, PREPEND, RANDOM, RANGE, REBALANCE
local RECONFIGURE, REDUCE, REPLACE, ROUND, SAMPLE, SATURDAY, SECONDS
local SEPTEMBER, SET_DIFFERENCE, SET_INSERT, SET_INTERSECTION, SET_UNION, SKIP
local SLICE, SPLICE_AT, SPLIT, STATUS, SUB, SUM, SUNDAY, SYNC, TABLE
local TABLE_CREATE, TABLE_DROP, TABLE_LIST, THURSDAY, TIME, TIMEZONE
local TIME_OF_DAY, TO_EPOCH_TIME, TO_GEOJSON, TO_ISO8601, TO_JSON_STRING
local TUESDAY, TYPE_OF, UNGROUP, UNION, UPCASE, UPDATE, UUID, VALUES, VAR
local WAIT, WEDNESDAY, WITHOUT, WITH_FIELDS, YEAR, ZIP

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

  add = function(...) return ADD({}, ...) end,
  and_ = function(...) return AND({}, ...) end,
  append = function(...) return APPEND({}, ...) end,
  april = function(...) return APRIL({}, ...) end,
  args = function(...) return ARGS({}, ...) end,
  asc = function(...) return ASC({}, ...) end,
  august = function(...) return AUGUST({}, ...) end,
  avg = function(...) return AVG({}, ...) end,
  between = function(arg0, arg1, arg2, opts) return BETWEEN(opts, arg0, arg1, arg2) end,
  binary = function(...) return BINARY({}, ...) end,
  index = function(...) return BRACKET({}, ...) end,
  branch = function(...) return BRANCH({}, ...) end,
  ceil = function(...) return CEIL({}, ...) end,
  changes = function(...) return CHANGES({}, ...) end,
  change_at = function(...) return CHANGE_AT({}, ...) end,
  circle = function(...) return CIRCLE(get_opts(...)) end,
  coerce_to = function(...) return COERCE_TO({}, ...) end,
  concat_map = function(...) return CONCAT_MAP({}, ...) end,
  config = function(...) return CONFIG({}, ...) end,
  contains = function(...) return CONTAINS({}, ...) end,
  count = function(...) return COUNT({}, ...) end,
  date = function(...) return DATE({}, ...) end,
  day = function(...) return DAY({}, ...) end,
  day_of_week = function(...) return DAY_OF_WEEK({}, ...) end,
  day_of_year = function(...) return DAY_OF_YEAR({}, ...) end,
  db = function(...) return DB({}, ...) end,
  db_create = function(...) return DB_CREATE({}, ...) end,
  db_drop = function(...) return DB_DROP({}, ...) end,
  db_list = function(...) return DB_LIST({}, ...) end,
  december = function(...) return DECEMBER({}, ...) end,
  default = function(...) return DEFAULT({}, ...) end,
  delete = function(...) return DELETE(get_opts(...)) end,
  delete_at = function(...) return DELETE_AT({}, ...) end,
  desc = function(...) return DESC({}, ...) end,
  difference = function(...) return DIFFERENCE({}, ...) end,
  distance = function(arg0, arg1, opts) return DISTANCE(opts, arg0, arg1) end,
  distinct = function(...) return DISTINCT(get_opts(...)) end,
  div = function(...) return DIV({}, ...) end,
  downcase = function(...) return DOWNCASE({}, ...) end,
  during = function(arg0, arg1, arg2, opts) return DURING(opts, arg0, arg1, arg2) end,
  epoch_time = function(...) return EPOCH_TIME({}, ...) end,
  eq = function(...) return EQ({}, ...) end,
  eq_join = function(...) return EQ_JOIN(get_opts(...)) end,
  error_ = function(...) return ERROR({}, ...) end,
  february = function(...) return FEBRUARY({}, ...) end,
  fill = function(...) return FILL({}, ...) end,
  filter = function(arg0, arg1, opts) return FILTER(opts, arg0, arg1) end,
  floor = function(...) return FLOOR({}, ...) end,
  for_each = function(...) return FOR_EACH({}, ...) end,
  friday = function(...) return FRIDAY({}, ...) end,
  func = function(...) return FUNC({}, ...) end,
  do_ = function(...) return FUNCALL({}, ...) end,
  ge = function(...) return GE({}, ...) end,
  geojson = function(...) return GEOJSON({}, ...) end,
  get = function(...) return GET({}, ...) end,
  get_all = function(...) return GET_ALL(get_opts(...)) end,
  get_field = function(...) return GET_FIELD({}, ...) end,
  get_intersecting = function(...) return GET_INTERSECTING(get_opts(...)) end,
  get_nearest = function(...) return GET_NEAREST(get_opts(...)) end,
  group = function(...) return GROUP(get_opts(...)) end,
  gt = function(...) return GT({}, ...) end,
  has_fields = function(...) return HAS_FIELDS({}, ...) end,
  hours = function(...) return HOURS({}, ...) end,
  http = function(...) return HTTP(get_opts(...)) end,
  includes = function(...) return INCLUDES({}, ...) end,
  index_create = function(...) return INDEX_CREATE(get_opts(...)) end,
  index_drop = function(...) return INDEX_DROP({}, ...) end,
  index_list = function(...) return INDEX_LIST({}, ...) end,
  index_rename = function(...) return INDEX_RENAME(get_opts(...)) end,
  index_status = function(...) return INDEX_STATUS({}, ...) end,
  index_wait = function(...) return INDEX_WAIT({}, ...) end,
  info = function(...) return INFO({}, ...) end,
  inner_join = function(...) return INNER_JOIN({}, ...) end,
  insert = function(arg0, arg1, opts) return INSERT(opts, arg0, arg1) end,
  insert_at = function(...) return INSERT_AT({}, ...) end,
  intersects = function(...) return INTERSECTS({}, ...) end,
  in_timezone = function(...) return IN_TIMEZONE({}, ...) end,
  iso8601 = function(...) return ISO8601(get_opts(...)) end,
  is_empty = function(...) return IS_EMPTY({}, ...) end,
  january = function(...) return JANUARY({}, ...) end,
  js = function(...) return JAVASCRIPT(get_opts(...)) end,
  json = function(...) return JSON({}, ...) end,
  july = function(...) return JULY({}, ...) end,
  june = function(...) return JUNE({}, ...) end,
  keys = function(...) return KEYS({}, ...) end,
  le = function(...) return LE({}, ...) end,
  limit = function(...) return LIMIT({}, ...) end,
  line = function(...) return LINE({}, ...) end,
  literal = function(...) return LITERAL({}, ...) end,
  lt = function(...) return LT({}, ...) end,
  make_array = function(...) return MAKE_ARRAY({}, ...) end,
  make_obj = function(...) return MAKE_OBJ({}, ...) end,
  map = function(...) return MAP({}, ...) end,
  march = function(...) return MARCH({}, ...) end,
  match = function(...) return MATCH({}, ...) end,
  max = function(...) return MAX({}, ...) end,
  maxval = function(...) return MAXVAL({}, ...) end,
  may = function(...) return MAY({}, ...) end,
  merge = function(...) return MERGE({}, ...) end,
  min = function(...) return MIN({}, ...) end,
  minutes = function(...) return MINUTES({}, ...) end,
  minval = function(...) return MINVAL({}, ...) end,
  mod = function(...) return MOD({}, ...) end,
  monday = function(...) return MONDAY({}, ...) end,
  month = function(...) return MONTH({}, ...) end,
  mul = function(...) return MUL({}, ...) end,
  ne = function(...) return NE({}, ...) end,
  not_ = function(...) return NOT({}, ...) end,
  november = function(...) return NOVEMBER({}, ...) end,
  now = function(...) return NOW({}, ...) end,
  nth = function(...) return NTH({}, ...) end,
  object = function(...) return OBJECT({}, ...) end,
  october = function(...) return OCTOBER({}, ...) end,
  offsets_of = function(...) return OFFSETS_OF({}, ...) end,
  or_ = function(...) return OR({}, ...) end,
  order_by = function(...) return ORDER_BY(get_opts(...)) end,
  outer_join = function(...) return OUTER_JOIN({}, ...) end,
  pluck = function(...) return PLUCK({}, ...) end,
  point = function(...) return POINT({}, ...) end,
  polygon = function(...) return POLYGON({}, ...) end,
  polygon_sub = function(...) return POLYGON_SUB({}, ...) end,
  prepend = function(...) return PREPEND({}, ...) end,
  random = function(...) return RANDOM(get_opts(...)) end,
  range = function(...) return RANGE({}, ...) end,
  rebalance = function(...) return REBALANCE({}, ...) end,
  reconfigure = function(...) return RECONFIGURE({}, ...) end,
  reduce = function(...) return REDUCE({}, ...) end,
  replace = function(...) return REPLACE(get_opts(...)) end,
  round = function(...) return ROUND({}, ...) end,
  sample = function(...) return SAMPLE({}, ...) end,
  saturday = function(...) return SATURDAY({}, ...) end,
  seconds = function(...) return SECONDS({}, ...) end,
  september = function(...) return SEPTEMBER({}, ...) end,
  set_difference = function(...) return SET_DIFFERENCE({}, ...) end,
  set_insert = function(...) return SET_INSERT({}, ...) end,
  set_intersection = function(...) return SET_INTERSECTION({}, ...) end,
  set_union = function(...) return SET_UNION({}, ...) end,
  skip = function(...) return SKIP({}, ...) end,
  slice = function(...) return SLICE(get_opts(...)) end,
  splice_at = function(...) return SPLICE_AT({}, ...) end,
  split = function(...) return SPLIT({}, ...) end,
  status = function(...) return STATUS({}, ...) end,
  sub = function(...) return SUB({}, ...) end,
  sum = function(...) return SUM({}, ...) end,
  sunday = function(...) return SUNDAY({}, ...) end,
  sync = function(...) return SYNC({}, ...) end,
  table = function(...) return TABLE(get_opts(...)) end,
  table_create = function(...) return TABLE_CREATE(get_opts(...)) end,
  table_drop = function(...) return TABLE_DROP({}, ...) end,
  table_list = function(...) return TABLE_LIST({}, ...) end,
  thursday = function(...) return THURSDAY({}, ...) end,
  time = function(...) return TIME({}, ...) end,
  timezone = function(...) return TIMEZONE({}, ...) end,
  time_of_day = function(...) return TIME_OF_DAY({}, ...) end,
  to_epoch_time = function(...) return TO_EPOCH_TIME({}, ...) end,
  to_geojson = function(...) return TO_GEOJSON({}, ...) end,
  to_iso8601 = function(...) return TO_ISO8601({}, ...) end,
  to_json_string = function(...) return TO_JSON_STRING({}, ...) end,
  tuesday = function(...) return TUESDAY({}, ...) end,
  type_of = function(...) return TYPE_OF({}, ...) end,
  ungroup = function(...) return UNGROUP({}, ...) end,
  union = function(...) return UNION({}, ...) end,
  upcase = function(...) return UPCASE({}, ...) end,
  update = function(arg0, arg1, opts) return UPDATE(opts, arg0, arg1) end,
  uuid = function(...) return UUID({}, ...) end,
  values = function(...) return VALUES({}, ...) end,
  var = function(...) return VAR({}, ...) end,
  wait = function(...) return WAIT({}, ...) end,
  wednesday = function(...) return WEDNESDAY({}, ...) end,
  without = function(...) return WITHOUT({}, ...) end,
  with_fields = function(...) return WITH_FIELDS({}, ...) end,
  year = function(...) return YEAR({}, ...) end,
  zip = function(...) return ZIP({}, ...) end
}

class_methods = {
  __init = function(self, optargs, ...)
    local args = {...}
    optargs = optargs or {}
    if self.tt == 69 then
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
    elseif self.tt == 155 then
      local data = args[1]
      if r.is_instance(data, 'ReQLOp') then
      elseif type(data) == 'string' then
        self.base64_data = r._b64(table.remove(args, 1))
      else
        return error('Parameter to `r.binary` must be a string or ReQL query.')
      end
    elseif self.tt == 64 then
      local func = table.remove(args)
      if type(func) == 'function' then
        func = FUNC({arity = #args}, func)
      end
      table.insert(args, 1, func)
    elseif self.tt == 37 then
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
    if self.tt == 155 and (not self.args[1]) then
      return {
        ['$reql_type$'] = 'BINARY',
        data = self.base64_data
      }
    end
    if self.tt == 3 then
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
    if self.tt == 2 then
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
    if self.tt == 3 then
      return kved(optargs)
    end
    if self.tt == 10 then
      return {'var_' .. args[1]}
    end
    if self.tt == 155 and not self.args[1] then
      return 'r.binary(<data>)'
    end
    if self.tt == 170 then
      return {
        args[1],
        '(',
        args[2],
        ')'
      }
    end
    if self.tt == 69 then
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
    if self.tt == 64 then
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
  ADD = ast('ADD', {tt = 24, st = 'add'}),
  AND = ast('AND', {tt = 67, st = 'and_'}),
  APPEND = ast('APPEND', {tt = 29, st = 'append'}),
  APRIL = ast('APRIL', {tt = 117, st = 'april'}),
  ARGS = ast('ARGS', {tt = 154, st = 'args'}),
  ASC = ast('ASC', {tt = 73, st = 'asc'}),
  AUGUST = ast('AUGUST', {tt = 121, st = 'august'}),
  AVG = ast('AVG', {tt = 146, st = 'avg'}),
  BETWEEN = ast('BETWEEN', {tt = 182, st = 'between'}),
  BINARY = ast('BINARY', {tt = 155, st = 'binary'}),
  BRACKET = ast('BRACKET', {tt = 170, st = 'index'}),
  BRANCH = ast('BRANCH', {tt = 65, st = 'branch'}),
  CEIL = ast('CEIL', {tt = 184, st = 'ceil'}),
  CHANGES = ast('CHANGES', {tt = 152, st = 'changes'}),
  CHANGE_AT = ast('CHANGE_AT', {tt = 84, st = 'change_at'}),
  CIRCLE = ast('CIRCLE', {tt = 165, st = 'circle'}),
  COERCE_TO = ast('COERCE_TO', {tt = 51, st = 'coerce_to'}),
  CONCAT_MAP = ast('CONCAT_MAP', {tt = 40, st = 'concat_map'}),
  CONFIG = ast('CONFIG', {tt = 174, st = 'config'}),
  CONTAINS = ast('CONTAINS', {tt = 93, st = 'contains'}),
  COUNT = ast('COUNT', {tt = 43, st = 'count'}),
  DATE = ast('DATE', {tt = 106, st = 'date'}),
  DAY = ast('DAY', {tt = 130, st = 'day'}),
  DAY_OF_WEEK = ast('DAY_OF_WEEK', {tt = 131, st = 'day_of_week'}),
  DAY_OF_YEAR = ast('DAY_OF_YEAR', {tt = 132, st = 'day_of_year'}),
  DB = ast('DB', {tt = 14, st = 'db'}),
  DB_CREATE = ast('DB_CREATE', {tt = 57, st = 'db_create'}),
  DB_DROP = ast('DB_DROP', {tt = 58, st = 'db_drop'}),
  DB_LIST = ast('DB_LIST', {tt = 59, st = 'db_list'}),
  DECEMBER = ast('DECEMBER', {tt = 125, st = 'december'}),
  DEFAULT = ast('DEFAULT', {tt = 92, st = 'default'}),
  DELETE = ast('DELETE', {tt = 54, st = 'delete'}),
  DELETE_AT = ast('DELETE_AT', {tt = 83, st = 'delete_at'}),
  DESC = ast('DESC', {tt = 74, st = 'desc'}),
  DIFFERENCE = ast('DIFFERENCE', {tt = 95, st = 'difference'}),
  DISTANCE = ast('DISTANCE', {tt = 162, st = 'distance'}),
  DISTINCT = ast('DISTINCT', {tt = 42, st = 'distinct'}),
  DIV = ast('DIV', {tt = 27, st = 'div'}),
  DOWNCASE = ast('DOWNCASE', {tt = 142, st = 'downcase'}),
  DURING = ast('DURING', {tt = 105, st = 'during'}),
  EPOCH_TIME = ast('EPOCH_TIME', {tt = 101, st = 'epoch_time'}),
  EQ = ast('EQ', {tt = 17, st = 'eq'}),
  EQ_JOIN = ast('EQ_JOIN', {tt = 50, st = 'eq_join'}),
  ERROR = ast('ERROR', {tt = 12, st = 'error_'}),
  FEBRUARY = ast('FEBRUARY', {tt = 115, st = 'february'}),
  FILL = ast('FILL', {tt = 167, st = 'fill'}),
  FILTER = ast('FILTER', {tt = 39, st = 'filter'}),
  FLOOR = ast('FLOOR', {tt = 183, st = 'floor'}),
  FOR_EACH = ast('FOR_EACH', {tt = 68, st = 'for_each'}),
  FRIDAY = ast('FRIDAY', {tt = 111, st = 'friday'}),
  FUNC = ast('FUNC', {tt = 69, st = 'func'}),
  FUNCALL = ast('FUNCALL', {tt = 64, st = 'do_'}),
  GE = ast('GE', {tt = 22, st = 'ge'}),
  GEOJSON = ast('GEOJSON', {tt = 157, st = 'geojson'}),
  GET = ast('GET', {tt = 16, st = 'get'}),
  GET_ALL = ast('GET_ALL', {tt = 78, st = 'get_all'}),
  GET_FIELD = ast('GET_FIELD', {tt = 31, st = 'get_field'}),
  GET_INTERSECTING = ast('GET_INTERSECTING', {tt = 166, st = 'get_intersecting'}),
  GET_NEAREST = ast('GET_NEAREST', {tt = 168, st = 'get_nearest'}),
  GROUP = ast('GROUP', {tt = 144, st = 'group'}),
  GT = ast('GT', {tt = 21, st = 'gt'}),
  HAS_FIELDS = ast('HAS_FIELDS', {tt = 32, st = 'has_fields'}),
  HOURS = ast('HOURS', {tt = 133, st = 'hours'}),
  HTTP = ast('HTTP', {tt = 153, st = 'http'}),
  INCLUDES = ast('INCLUDES', {tt = 164, st = 'includes'}),
  INDEX_CREATE = ast('INDEX_CREATE', {tt = 75, st = 'index_create'}),
  INDEX_DROP = ast('INDEX_DROP', {tt = 76, st = 'index_drop'}),
  INDEX_LIST = ast('INDEX_LIST', {tt = 77, st = 'index_list'}),
  INDEX_RENAME = ast('INDEX_RENAME', {tt = 156, st = 'index_rename'}),
  INDEX_STATUS = ast('INDEX_STATUS', {tt = 139, st = 'index_status'}),
  INDEX_WAIT = ast('INDEX_WAIT', {tt = 140, st = 'index_wait'}),
  INFO = ast('INFO', {tt = 79, st = 'info'}),
  INNER_JOIN = ast('INNER_JOIN', {tt = 48, st = 'inner_join'}),
  INSERT = ast('INSERT', {tt = 56, st = 'insert'}),
  INSERT_AT = ast('INSERT_AT', {tt = 82, st = 'insert_at'}),
  INTERSECTS = ast('INTERSECTS', {tt = 163, st = 'intersects'}),
  IN_TIMEZONE = ast('IN_TIMEZONE', {tt = 104, st = 'in_timezone'}),
  ISO8601 = ast('ISO8601', {tt = 99, st = 'iso8601'}),
  IS_EMPTY = ast('IS_EMPTY', {tt = 86, st = 'is_empty'}),
  JANUARY = ast('JANUARY', {tt = 114, st = 'january'}),
  JAVASCRIPT = ast('JAVASCRIPT', {tt = 11, st = 'js'}),
  JSON = ast('JSON', {tt = 98, st = 'json'}),
  JULY = ast('JULY', {tt = 120, st = 'july'}),
  JUNE = ast('JUNE', {tt = 119, st = 'june'}),
  KEYS = ast('KEYS', {tt = 94, st = 'keys'}),
  LE = ast('LE', {tt = 20, st = 'le'}),
  LIMIT = ast('LIMIT', {tt = 71, st = 'limit'}),
  LINE = ast('LINE', {tt = 160, st = 'line'}),
  LITERAL = ast('LITERAL', {tt = 137, st = 'literal'}),
  LT = ast('LT', {tt = 19, st = 'lt'}),
  MAKE_ARRAY = ast('MAKE_ARRAY', {tt = 2, st = 'make_array'}),
  MAKE_OBJ = ast('MAKE_OBJ', {tt = 3, st = 'make_obj'}),
  MAP = ast('MAP', {tt = 38, st = 'map'}),
  MARCH = ast('MARCH', {tt = 116, st = 'march'}),
  MATCH = ast('MATCH', {tt = 97, st = 'match'}),
  MAX = ast('MAX', {tt = 148, st = 'max'}),
  MAXVAL = ast('MAXVAL', {tt = 181, st = 'maxval'}),
  MAY = ast('MAY', {tt = 118, st = 'may'}),
  MERGE = ast('MERGE', {tt = 35, st = 'merge'}),
  MIN = ast('MIN', {tt = 147, st = 'min'}),
  MINUTES = ast('MINUTES', {tt = 134, st = 'minutes'}),
  MINVAL = ast('MINVAL', {tt = 180, st = 'minval'}),
  MOD = ast('MOD', {tt = 28, st = 'mod'}),
  MONDAY = ast('MONDAY', {tt = 107, st = 'monday'}),
  MONTH = ast('MONTH', {tt = 129, st = 'month'}),
  MUL = ast('MUL', {tt = 26, st = 'mul'}),
  NE = ast('NE', {tt = 18, st = 'ne'}),
  NOT = ast('NOT', {tt = 23, st = 'not_'}),
  NOVEMBER = ast('NOVEMBER', {tt = 124, st = 'november'}),
  NOW = ast('NOW', {tt = 103, st = 'now'}),
  NTH = ast('NTH', {tt = 45, st = 'nth'}),
  OBJECT = ast('OBJECT', {tt = 143, st = 'object'}),
  OCTOBER = ast('OCTOBER', {tt = 123, st = 'october'}),
  OFFSETS_OF = ast('OFFSETS_OF', {tt = 87, st = 'offsets_of'}),
  OR = ast('OR', {tt = 66, st = 'or_'}),
  ORDER_BY = ast('ORDER_BY', {tt = 41, st = 'order_by'}),
  OUTER_JOIN = ast('OUTER_JOIN', {tt = 49, st = 'outer_join'}),
  PLUCK = ast('PLUCK', {tt = 33, st = 'pluck'}),
  POINT = ast('POINT', {tt = 159, st = 'point'}),
  POLYGON = ast('POLYGON', {tt = 161, st = 'polygon'}),
  POLYGON_SUB = ast('POLYGON_SUB', {tt = 171, st = 'polygon_sub'}),
  PREPEND = ast('PREPEND', {tt = 80, st = 'prepend'}),
  RANDOM = ast('RANDOM', {tt = 151, st = 'random'}),
  RANGE = ast('RANGE', {tt = 173, st = 'range'}),
  REBALANCE = ast('REBALANCE', {tt = 179, st = 'rebalance'}),
  RECONFIGURE = ast('RECONFIGURE', {tt = 176, st = 'reconfigure'}),
  REDUCE = ast('REDUCE', {tt = 37, st = 'reduce'}),
  REPLACE = ast('REPLACE', {tt = 55, st = 'replace'}),
  ROUND = ast('ROUND', {tt = 185, st = 'round'}),
  SAMPLE = ast('SAMPLE', {tt = 81, st = 'sample'}),
  SATURDAY = ast('SATURDAY', {tt = 112, st = 'saturday'}),
  SECONDS = ast('SECONDS', {tt = 135, st = 'seconds'}),
  SEPTEMBER = ast('SEPTEMBER', {tt = 122, st = 'september'}),
  SET_DIFFERENCE = ast('SET_DIFFERENCE', {tt = 91, st = 'set_difference'}),
  SET_INSERT = ast('SET_INSERT', {tt = 88, st = 'set_insert'}),
  SET_INTERSECTION = ast('SET_INTERSECTION', {tt = 89, st = 'set_intersection'}),
  SET_UNION = ast('SET_UNION', {tt = 90, st = 'set_union'}),
  SKIP = ast('SKIP', {tt = 70, st = 'skip'}),
  SLICE = ast('SLICE', {tt = 30, st = 'slice'}),
  SPLICE_AT = ast('SPLICE_AT', {tt = 85, st = 'splice_at'}),
  SPLIT = ast('SPLIT', {tt = 149, st = 'split'}),
  STATUS = ast('STATUS', {tt = 175, st = 'status'}),
  SUB = ast('SUB', {tt = 25, st = 'sub'}),
  SUM = ast('SUM', {tt = 145, st = 'sum'}),
  SUNDAY = ast('SUNDAY', {tt = 113, st = 'sunday'}),
  SYNC = ast('SYNC', {tt = 138, st = 'sync'}),
  TABLE = ast('TABLE', {tt = 15, st = 'table'}),
  TABLE_CREATE = ast('TABLE_CREATE', {tt = 60, st = 'table_create'}),
  TABLE_DROP = ast('TABLE_DROP', {tt = 61, st = 'table_drop'}),
  TABLE_LIST = ast('TABLE_LIST', {tt = 62, st = 'table_list'}),
  THURSDAY = ast('THURSDAY', {tt = 110, st = 'thursday'}),
  TIME = ast('TIME', {tt = 136, st = 'time'}),
  TIMEZONE = ast('TIMEZONE', {tt = 127, st = 'timezone'}),
  TIME_OF_DAY = ast('TIME_OF_DAY', {tt = 126, st = 'time_of_day'}),
  TO_EPOCH_TIME = ast('TO_EPOCH_TIME', {tt = 102, st = 'to_epoch_time'}),
  TO_GEOJSON = ast('TO_GEOJSON', {tt = 158, st = 'to_geojson'}),
  TO_ISO8601 = ast('TO_ISO8601', {tt = 100, st = 'to_iso8601'}),
  TO_JSON_STRING = ast('TO_JSON_STRING', {tt = 172, st = 'to_json_string'}),
  TUESDAY = ast('TUESDAY', {tt = 108, st = 'tuesday'}),
  TYPE_OF = ast('TYPE_OF', {tt = 52, st = 'type_of'}),
  UNGROUP = ast('UNGROUP', {tt = 150, st = 'ungroup'}),
  UNION = ast('UNION', {tt = 44, st = 'union'}),
  UPCASE = ast('UPCASE', {tt = 141, st = 'upcase'}),
  UPDATE = ast('UPDATE', {tt = 53, st = 'update'}),
  UUID = ast('UUID', {tt = 169, st = 'uuid'}),
  VALUES = ast('VALUES', {tt = 186, st = 'values'}),
  VAR = ast('VAR', {tt = 10, st = 'var'}),
  WAIT = ast('WAIT', {tt = 177, st = 'wait'}),
  WEDNESDAY = ast('WEDNESDAY', {tt = 109, st = 'wednesday'}),
  WITHOUT = ast('WITHOUT', {tt = 34, st = 'without'}),
  WITH_FIELDS = ast('WITH_FIELDS', {tt = 96, st = 'with_fields'}),
  YEAR = ast('YEAR', {tt = 128, st = 'year'}),
  ZIP = ast('ZIP', {tt = 72, st = 'zip'}),
}
