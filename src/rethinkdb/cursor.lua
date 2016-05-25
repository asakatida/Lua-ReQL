--- Interface to handle query responses.
-- @module rethinkdb.cursor
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local errors = require'rethinkdb.errors'
local proto = require'rethinkdb.protodef'
local convert_pseudotype = require'rethinkdb.convert_pseudotype'

local Response = proto.Response

local COMPILE_ERROR = Response.COMPILE_ERROR
local SUCCESS_ATOM = Response.SUCCESS_ATOM
local SUCCESS_PARTIAL = Response.SUCCESS_PARTIAL
local SUCCESS_SEQUENCE = Response.SUCCESS_SEQUENCE
local CLIENT_ERROR = Response.CLIENT_ERROR
local RUNTIME_ERROR = Response.RUNTIME_ERROR
local WAIT_COMPLETE = Response.WAIT_COMPLETE

local function cursor(...)
  local r, del_query, end_query, get_response, token, opts, root = ...

  local responses = {}
  local _cb, end_flag, _type

  local function run_cb(cb)
    local response = responses[1]
    -- Behavior varies considerably based on response type
    -- Error responses are not discarded, and the error will be sent to all future callbacks
    local t = response.t
    if t == SUCCESS_ATOM or t == SUCCESS_PARTIAL or t == SUCCESS_SEQUENCE then
      local row, err = convert_pseudotype(r, response.r[1], opts)

      if err then
        row = response.r[1]
      end

      table.remove(response.r, 1)
      if not next(response.r) then table.remove(responses, 1) end

      return cb(err, row)
    end
    _cb = nil
    if t == COMPILE_ERROR then
      return cb(errors.ReQLCompileError(response.r[1], root, response.b))
    elseif t == CLIENT_ERROR then
      return cb(errors.ReQLClientError(response.r[1], root, response.b))
    elseif t == RUNTIME_ERROR then
      return cb(errors.ReQLRuntimeError(response.r[1], root, response.b))
    elseif t == WAIT_COMPLETE then
      return cb()
    end
    return cb(errors.ReQLDriverError('Unknown response type ' .. t))
  end

  local inst = {}

  function inst.set(cb)
    _cb = cb
  end

  function inst.close(cb)
    if not end_flag then
      end_flag = true
      end_query(token)
    end
    if cb then return cb() end
  end

  function inst.each(callback, on_finished)
    local e
    local function cb(err, data)
      e = err
      return callback(data)
    end
    inst.set(cb)
    while not end_flag do
      get_response(token)
    end
    if on_finished then
      return on_finished(e)
    end
  end

  function inst.next(callback)
    if end_flag then
      return callback(errors.ReQLDriverError('No more rows in the cursor.'))
    end
    local old_cb = nil
    local function cb(err, res)
      inst.set(old_cb)
      return callback(err, res)
    end
    old_cb, _cb = _cb, old_cb
    inst.set(cb)
    local status, err = pcall(get_response, token)
    if status then
      return run_cb(cb)
    end
    return cb(err)
  end

  function inst.to_array(callback)
    local arr = {}

    local function cb(row)
      table.insert(arr, row)
    end

    local function on_finished(err)
      return callback(err, arr)
    end

    return inst.each(cb, on_finished)
  end
  
  local function add_response(response)
    local t = response.t
    if not _type then
      if response.n then
        _type = response.n
      else
        _type = 'finite'
      end
    end
    if response.r[1] or t == WAIT_COMPLETE then
      table.insert(responses, response)
    end
    if t ~= SUCCESS_PARTIAL then
      -- We got the final document for this cursor
      end_flag = true
      del_query(token)
    end
    while _cb and responses[1] do
      run_cb(_cb)
    end
  end

  return inst, add_response
end

return cursor
