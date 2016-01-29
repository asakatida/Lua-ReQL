return require('rethinkdb.class')(
  'Cursor',
  {
    __init = function(self, conn, token, opts, root)
      self._conn = conn
      self.delete = function()
        return conn:_del_query(token)
      end
      self._end = function()
        return conn:_end_query(token)
      end
      self.get_response = function()
        return conn:_get_response(token)
      end
      self.convert_pseudotype = function(response)
        return pcall(convert_pseudotype, response.r[1], opts)
      end
      self._root = root -- current query
      self._responses = {}
    end,
    _add_response = function(self, response)
      local t = response.t
      if not self._type then
        if response.n then
          self._type = response.n
          self._conn.weight = self._conn.weight + 2
        else
          self._type = 'finite'
        end
      end
      if response.r[1] or t == 4 then
        table.insert(self._responses, response)
      end
      if t ~= 3 then
        -- We got an error, SUCCESS_SEQUENCE, WAIT_COMPLETE, or a SUCCESS_ATOM
        self._end_flag = true
        self.delete()
      end
      while self._cb and self._responses[1] do
        self:_run_cb(self._cb)
      end
    end,
    _run_cb = function(self, cb)
      local response = self._responses[1]
      -- Behavior varies considerably based on response type
      -- Error responses are not discarded, and the error will be sent to all future callbacks
      local t = response.t
      if t == 1 or t == 3 or t == 2 then
        local err
        local status, row = self.convert_pseudotype(response)
        if not status then
          err = row
          row = response.r[1]
        end

        table.remove(response.r, 1)
        if not next(response.r) then table.remove(self._responses, 1) end

        return cb(err, row)
      end
      self:set()
      if t == 17 then
        return cb(ReQLCompileError(response.r[1], self._root, response.b))
      elseif t == 16 then
        return cb(ReQLClientError(response.r[1], self._root, response.b))
      elseif t == 18 then
        return cb(ReQLRuntimeError(response.r[1], self._root, response.b))
      elseif t == 4 then
        return cb()
      end
      return cb(ReQLDriverError('Unknown response type ' .. t))
    end,
    set = function(self, cb)
      self._cb = cb
    end,
    next = function(self, cb)
      if self._end_flag then
        return cb(ReQLDriverError('No more rows in the cursor.'))
      end
      local _cb = self._cb
      --set(function(err, res)
        --self._cb = _cb
        --return cb(err, res)
      --end)
      local err, res = self.get_response()
      return cb(err, res)
    end,
    close = function(self, cb)
      if not self._end_flag then
        self._end_flag = true
        self._end()
      end
      if cb then return cb() end
    end,
    each = function(self, cb, on_finished)
      local e
      self:set(function(err, data)
        e = err
        return cb(data)
      end)
      while not self._end_flag do
        self.get_response()
      end
      if on_finished then
        return on_finished(e)
      end
    end,
    to_array = function(self, callback)
      local arr = {}
      return self:each(
        function(row)
          table.insert(arr, row)
        end,
        function(err)
          return callback(err, arr)
        end
      )
    end,
  }
)
