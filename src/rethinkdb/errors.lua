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

local function new_error_type(name, parent)
  return function(msg, term, frames)
    local inst = {__name = name}

    function inst.message()
      local _message = name .. ' ' .. msg
      if term then
        _message = _message .. ' in:\n' .. print_query(term, frames)
      end
      function inst.message()
        return _message
      end
      return _message
    end

    inst.__parent = parent
    inst.msg = msg

    return setmetatable(inst, {__index = inst.__parent})
  end
end

local ReQLError = {__name = 'ReQLError'}

local ReQLDriverError = new_error_type('ReQLDriverError', ReQLError)
local ReQLServerError = new_error_type('ReQLServerError', ReQLError)()

local ReQLRuntimeError = new_error_type('ReQLRuntimeError', ReQLServerError)

local ReQLAvailabilityError = new_error_type('ReQLAvailabilityError', ReQLRuntimeError())
local ReQLQueryLogicError = new_error_type('ReQLQueryLogicError', ReQLRuntimeError())

return {
  ReQLDriverError = ReQLDriverError,

  ReQLRuntimeError = ReQLRuntimeError,
  ReQLCompileError = new_error_type('ReQLCompileError', ReQLServerError),

  ReQLAuthError = new_error_type('ReQLAuthError', ReQLDriverError()),

  ReQLClientError = new_error_type('ReQLClientError', ReQLServerError),

  ReQLAvailabilityError = ReQLAvailabilityError,
  ReQLInternalError = new_error_type('ReQLInternalError', ReQLRuntimeError()),
  ReQLQueryLogicError = ReQLQueryLogicError,
  ReQLResourceLimitError = new_error_type('ReQLResourceLimitError', ReQLRuntimeError()),
  ReQLTimeoutError = new_error_type('ReQLTimeoutError', ReQLRuntimeError()),
  ReQLUserError = new_error_type('ReQLUserError', ReQLRuntimeError()),

  ReQLOpFailedError = new_error_type('ReQLOpFailedError', ReQLAvailabilityError()),
  ReQLOpIndeterminateError = new_error_type('ReQLOpIndeterminateError', ReQLAvailabilityError()),

  ReQLNonExistenceError = new_error_type('ReQLNonExistenceError', ReQLQueryLogicError())
}
