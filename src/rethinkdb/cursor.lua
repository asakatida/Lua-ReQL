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

local COMPILE_ERROR = Response.COMPILE_ERROR
local CLIENT_ERROR = Response.CLIENT_ERROR
local RUNTIME_ERROR = Response.RUNTIME_ERROR
local SERVER_INFO = Response.SERVER_INFO
local SUCCESS_ATOM = Response.SUCCESS_ATOM
local SUCCESS_PARTIAL = Response.SUCCESS_PARTIAL
local SUCCESS_SEQUENCE = Response.SUCCESS_SEQUENCE
local WAIT_COMPLETE = Response.WAIT_COMPLETE

local INTERNAL = ErrorType.INTERNAL
local RESOURCE_LIMIT = ErrorType.RESOURCE_LIMIT
local QUERY_LOGIC = ErrorType.QUERY_LOGIC
local NON_EXISTENCE = ErrorType.NON_EXISTENCE
local OP_FAILED = ErrorType.OP_FAILED
local OP_INDETERMINATE = ErrorType.OP_INDETERMINATE
local USER = ErrorType.USER
local PERMISSION_ERROR = ErrorType.PERMISSION_ERROR

local function new_response(shared, response, reql_inst)
  -- Behavior varies considerably based on response type
  local t = response.t
  if not t == WAIT_COMPLETE then
    local function it()
    end
    return it
  end
  if t ~= SUCCESS_PARTIAL then
    -- We got the final document for this cursor
    shared.del_query()
  end
  if t == SERVER_INFO or t == SUCCESS_ATOM or t == SUCCESS_PARTIAL or t == SUCCESS_SEQUENCE then
    local ipairs_f, ipairs_s, ipairs_var = ipairs(response.r)
    local function it(state, prev)
      local res
      ipairs_var, res = ipairs_f(ipairs_s, ipairs_var)
      if ipairs_var ~= nil then
        return prev + 1, res
      end
      if t == SUCCESS_PARTIAL then
        local success, err = state.step()
        if not success then
          return 0, errors.ReQLDriverError(err)
        end
      end
    end
    return it, shared, 0
  end
  local r, b = response.r[1], response.b
  local function new(err)
    -- Error responses are not discarded, and the error will be sent to all future callbacks
    local function it()
      return 0, err(r, reql_inst, b)
    end
    return it
  end
  if t == COMPILE_ERROR then
    return new(errors.ReQLCompileError)
  elseif t == CLIENT_ERROR then
    return new(errors.ReQLClientError)
  elseif t == RUNTIME_ERROR then
    local e = response.e
    if e == INTERNAL then
      return new(errors.ReQLInternalError)
    elseif e == RESOURCE_LIMIT then
      return new(errors.ReQLResourceLimitError)
    elseif e == QUERY_LOGIC then
      return new(errors.ReQLQueryLogicError)
    elseif e == NON_EXISTENCE then
      return new(errors.ReQLNonExistenceError)
    elseif e == OP_FAILED then
      return new(errors.ReQLOpFailedError)
    elseif e == OP_INDETERMINATE then
      return new(errors.ReQLOpIndeterminateError)
    elseif e == USER then
      return new(errors.ReQLUserError)
    elseif e == PERMISSION_ERROR then
      return new(errors.ReQLPermissionsError)
    end
    return new(errors.ReQLRuntimeError)
  end
  local function it()
    return 0, errors.ReQLDriverError('unknown response type from server [' .. t .. '].')
  end
  return it
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

local function cursor(r, state, opts, term)
  local it, it_state, it_var

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
    it, it_state, it_var = new_response(state, response, term)
    while it and state.outstanding_callback do
      local row
      it_var, row = it(it_state, it_var)
      if not it_var and not state.open then
        it = nil
        cursor_inst.set()
        return
      end
      if it_var == 0 then
        it = nil
        state.outstanding_callback(row)
        cursor_inst.set()
        return
      end
      local err
      row, err = convert_pseudotype(cursor_inst.r, row, opts)
      if row == nil then
        state.outstanding_callback(err)
        it = nil
        cursor_inst.set()
        return
      else
        state.outstanding_callback(nil, row)
      end
    end
  end

  function cursor_inst.set(callback)
    state.outstanding_callback = callback
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
      state.del_query()
    end
    return cb()
  end

  function cursor_inst.each(callback, on_finished)
    if not callback then
      cursor_inst.set()
      local function f(pairs_state, var)
        local next_var, next_row = it(it_state, var)
        if not next_var then
          local success, err = state.step()
          if not success then
            return 0, errors.ReQLDriverError(err)
          end
          return f(pairs_state, var)
        end
        return next_var, next_row
      end
      return f, {}, it_var
    end
    local e
    local function cb(err, data)
      if err then
        e = err
        return
      end
      callback(data)
    end
    cursor_inst.set(cb)
    state.step()
    if not state.open then
      if on_finished then
        return on_finished(e)
      end
    end
  end

  function cursor_inst.to_array(callback)
    local arr = {}

    local function cb(row)
      table.insert(arr, row)
    end

    local function on_finished(err)
      if callback then
        return callback(err, arr)
      end
      if err then
        return nil, err, arr
      end
      return arr
    end

    return cursor_inst.each(cb, on_finished)
  end

  return cursor_inst
end

return cursor
