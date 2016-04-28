local errors = require'rethinkdb.errors'
local proto = require'rethinkdb.protodef'
local convert_pseudotype = require'rethinkdb.convert_pseudotype'

return function(del_query, end_query, get_response, token, opts, root)
  local responses = {}
  local _cb, end_flag, _type

  local run_cb = function(cb)
    local response = responses[1]
    -- Behavior varies considerably based on response type
    -- Error responses are not discarded, and the error will be sent to all future callbacks
    local t = response.t
    if t == proto.Response.SUCCESS_ATOM or t == proto.Response.SUCCESS_PARTIAL or t == proto.Response.SUCCESS_SEQUENCE then
      local err
      local status, row = pcall(convert_pseudotype, response.r[1], opts)
      if not status then
        err = row
        row = response.r[1]
      end

      table.remove(response.r, 1)
      if not next(response.r) then table.remove(responses, 1) end

      return cb(err, row)
    end
    _cb = nil
    if t == proto.Response.COMPILE_ERROR then
      return cb(errors.ReQLCompileError(response.r[1], root, response.b))
    elseif t == proto.Response.CLIENT_ERROR then
      return cb(errors.ReQLClientError(response.r[1], root, response.b))
    elseif t == proto.Response.RUNTIME_ERROR then
      return cb(errors.ReQLRuntimeError(response.r[1], root, response.b))
    elseif t == proto.Response.WAIT_COMPLETE then
      return cb()
    end
    return cb(errors.ReQLDriverError('Unknown response type ' .. t))
  end

  local inst = {
    __name = 'Cursor',
    set = function(cb)
      _cb = cb
    end
  }

  function inst.close(cb)
    if not end_flag then
      end_flag = true
      end_query(token)
    end
    if cb then return cb() end
  end

  function inst.each(cb, on_finished)
    local e
    _cb = function(err, data)
      e = err
      return cb(data)
    end
    while not end_flag do
      get_response(token)
    end
    if on_finished then
      return on_finished(e)
    end
  end

  function inst.next(cb)
    if end_flag then
      return cb(errors.ReQLDriverError('No more rows in the cursor.'))
    end
    --local __cb = _cb
    --_cb = function(err, res)
    --  _cb = __cb
    --  return cb(err, res)
    --end
    local err, res = get_response(token)
    return cb(err, res)
  end

  function inst.to_array(callback)
    local arr = {}
    return inst.each(
      function(row)
        table.insert(arr, row)
      end,
      function(err)
        return callback(err, arr)
      end
    )
  end

  return inst, function(response)
    local t = response.t
    if not _type then
      if response.n then
        _type = response.n
      else
        _type = 'finite'
      end
    end
    if response.r[1] or t == proto.Response.WAIT_COMPLETE then
      table.insert(responses, response)
    end
    if t ~= proto.Response.SUCCESS_PARTIAL then
      -- We got an error, SUCCESS_SEQUENCE, WAIT_COMPLETE, or a SUCCESS_ATOM
      end_flag = true
      del_query(token)
    end
    while _cb and responses[1] do
      run_cb(_cb)
    end
  end
end
