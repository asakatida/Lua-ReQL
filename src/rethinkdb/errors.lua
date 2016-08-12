--- Interface to the ReQL error heiarchy.
-- @module rethinkdb.errors
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

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

function errors_meta_table.__index(_, name)
  local function ReQLError(r, msg, term, frames)
    assert(msg)
    local error_inst = setmetatable({r = r, msg = msg}, error_inst_meta_table)

    local _name = name
    while _name do
      error_inst[_name] = error_inst
      _name = rawget(heiarchy, _name)
    end

    function error_inst.message()
      local _message = name .. ' ' .. error_inst.msg
      if term and frames then
        _message = _message .. ' in:\n[' .. table.concat(frames, ', ') .. ']'  -- @todo rewrite the query printer
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
