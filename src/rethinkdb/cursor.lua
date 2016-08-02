--- Interface for cursors.
-- @module rethinkdb.cursor
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local convert_pseudotype = require'rethinkdb.internal.convert_pseudotype'
local errors = require'rethinkdb.errors'
local protodef = require'rethinkdb.internal.protodef'

local Response = protodef.Response
local ErrorType = protodef.ErrorType

local SUCCESS_PARTIAL = Response.SUCCESS_PARTIAL
local WAIT_COMPLETE = Response.WAIT_COMPLETE

local basic_resposes = {
  [Response.SERVER_INFO] = true,
  [Response.SUCCESS_ATOM] = true,
  [Response.SUCCESS_PARTIAL] = true,
  [Response.SUCCESS_SEQUENCE] = true,
}

local error_types = {
  [Response.COMPILE_ERROR] = errors.ReQLCompileError,
  [Response.CLIENT_ERROR] = errors.ReQLClientError,
  [Response.RUNTIME_ERROR] = errors.ReQLRuntimeError,
}

local runtime_error_types = {
  [ErrorType.INTERNAL] = errors.ReQLInternalError,
  [ErrorType.NON_EXISTENCE] = errors.ReQLNonExistenceError,
  [ErrorType.OP_FAILED] = errors.ReQLOpFailedError,
  [ErrorType.OP_INDETERMINATE] = errors.ReQLOpIndeterminateError,
  [ErrorType.PERMISSION_ERROR] = errors.ReQLPermissionsError,
  [ErrorType.QUERY_LOGIC] = errors.ReQLQueryLogicError,
  [ErrorType.RESOURCE_LIMIT] = errors.ReQLResourceLimitError,
  [ErrorType.USER] = errors.ReQLUserError,
}

local function new_response(state, response, reql_inst)
  -- Behavior varies considerably based on response type
  local t = response.t
  if t ~= SUCCESS_PARTIAL then
    -- We got the final document for this cursor
    state.del_query()
  end
  local err = error_types[t]
  if err then
    local r, b = response.r[1], response.b
    local err_type = runtime_error_types[response.e]
    -- Error responses are not discarded, and the error will be sent to all future callbacks
    if err_type then
      local function it()
        return err_type(r, reql_inst, b)
      end
      return it
    end
    local function it()
      return err(r, reql_inst, b)
    end
    return it
  end
  if t == WAIT_COMPLETE then
    local function it()
    end
    return it
  end
  if basic_resposes[t] then
    local ipairs_f, ipairs_s, ipairs_var = ipairs(response.r)
    local function it()
      local res
      ipairs_var, res = ipairs_f(ipairs_s, ipairs_var)
      if ipairs_var ~= nil then
        return res
      end
    end
    return it
  end
  local function it()
    return errors.ReQLDriverError('unknown response type from server [' .. t .. '].')
  end
  return it
end

local function each(state, var)
  local row = state.it()
  if not row then
    if not state.open then
      return
    end
    local success, err = state.step()
    if not success then
      return 0, errors.ReQLDriverError(err)
    end
    return each(state, var)
  end
  return var + 1, row
end

local meta_table = {}

function meta_table.__tostring(cursor_inst)
  if cursor_inst.feed_type then
    return 'RethinkDB Cursor ' .. cursor_inst.feed_type
  end
  return 'RethinkDB Cursor'
end

function meta_table.__pairs(cursor_inst)
  return cursor_inst.each()
end

local function cursor(r, state, opts, reql_inst)
  local cursor_inst = setmetatable({r = r}, meta_table)

  function state.add_response(response)
    if not cursor_inst.feed_type then
      if response.n then
        for k, v in pairs(protodef.ResponseNote) do
          if v == response.n then
            cursor_inst.feed_type = k
          end
        end
      else
        cursor_inst.feed_type = 'finite'
      end
    end
    state.it = new_response(state, response, reql_inst)
    while state.outstanding_callback do
      local row = state.it()
      if not row then
        if not state.open then
          state.it = nil
          cursor_inst.set()
        end
        return true
      end
      if type(row) == 'table' and row.ReQLError then
        state.outstanding_callback(row)
        cursor_inst.set()
        return true
      end
      local err
      row, err = convert_pseudotype(cursor_inst.r, row, opts)
      if row == nil then
        state.outstanding_callback(err)
        state.it = nil
        cursor_inst.set()
        return true
      end
      state.outstanding_callback(nil, row)
    end
    return true
  end

  function cursor_inst.set(callback)
    state.outstanding_callback = callback
    if callback then
      state.maybe_response()
    end
  end

  function cursor_inst.close(callback)
    local function cb(err)
      if callback then return callback(err) end
      if err then
        return nil, err
      end
      return true
    end
    if state.open then
      local success, err = state.end_query()
      if not success then
        return cb(err)
      end
    end
    return cb()
  end

  function cursor_inst.each()
    cursor_inst.set()
    if not state.it then
      local success, err = state.step()
      if not success then
        return nil, errors.ReQLDriverError(err)
      end
    end
    return each, state, 0
  end

  function cursor_inst.to_array()
    local arr = {}

    for i, v in cursor_inst.each() do
      if i == 0 then
        return nil, v, arr
      end
      arr[i] = v
    end

    return arr
  end

  return cursor_inst
end

return cursor
