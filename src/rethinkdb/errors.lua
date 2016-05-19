--- Interface to the ReQL error heiarchy.
-- @module rethinkdb.errors

local carrot_marker = {}

local function carrotify(tree)
  return {carrot_marker, tree}
end

local function compose_term(term)
  if type(term) ~= 'table' then return '' .. term end
  local args = {}
  for i, arg in ipairs(term.args) do
    args[i] = compose_term(arg)
  end
  local optargs = {}
  for key, arg in pairs(term.optargs) do
    optargs[key] = compose_term(arg)
  end
  return term.compose(args, optargs)
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
    return term.compose(args, optargs)
  end
  return carrotify(term.compose(args, optargs))
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

local function __index(_, name)
  local function ReQLError(msg, term, frames)
    local inst = {msg = msg}

    local _name = name
    while _name do
      inst[_name] = inst
      _name = rawget(heiarchy, _name)
    end

    function inst.message()
      local _message = name .. ' ' .. inst.msg
      if term then
        _message = _message .. ' in:\n' .. print_query(term, frames)
      end
      function inst.message()
        return _message
      end
      return _message
    end

    return inst
  end

  return ReQLError
end

return setmetatable({}, {__index = __index})
