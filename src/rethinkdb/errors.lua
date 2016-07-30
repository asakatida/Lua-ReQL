--- Interface to the ReQL error heiarchy.
-- @module rethinkdb.errors
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local protect = require'rethinkdb.internal.protect'

--- get debug represention of query
-- @tab _args represention of arguments
-- @tab[opt] _optargs represention of options
-- @treturn string
local function compose(term, args, optargs)
  if term.st == 'datum' then
    if term.args[1] == nil then
      return 'nil'
    end
    return protect(term.r.encode, term.args[1]) or '...'
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
  if term.st == 'funcall' then
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

  ReQLClientError = 'ReQLServerError',
  ReQLCompileError = 'ReQLServerError',
  ReQLRuntimeError = 'ReQLServerError',

  ReQLAvailabilityError = 'ReQLRuntimeError',
  ReQLInternalError = 'ReQLRuntimeError',
  ReQLPermissionsError = 'ReQLRuntimeError',
  ReQLQueryLogicError = 'ReQLRuntimeError',
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

local errors = setmetatable({}, errors_meta_table)

return errors
