local m = {}

function m.init(r, _r)
  return function(host, _callback)
    local size
    local _open = false
    local pool = {}
    local builder = r.Connection(host)

    local function _start(term, callback, opts)
      local weight = math.huge
      if opts.conn then
        local good_conn = pool[opts.conn]
        if good_conn then
          return good_conn._start(term, callback, opts)
        end
      end
      local good_conn
      for i=1, size do
        if not pool[i] then pool[i] = builder.connect() end
        local conn = pool[i]
        if not conn.open() then
          conn.connect()
          pool[i] = conn
        end
        if conn.weight < weight then
          good_conn = conn
          weight = conn.weight
        end
      end
      return good_conn._start(term, callback, opts)
    end

    local function close(opts, callback)
      local err
      local cb = function(e)
        if e then
          err = e
        end
      end
      for _, conn in pairs(pool) do
        conn.close(opts, cb)
      end
      _open = false
      if callback then return callback(err) end
      return err
    end

    local function open()
      if not _open then return false end
      for _, conn in ipairs(pool) do
        if conn.open() then return true end
      end
      _open = false
      return false
    end

    local inst = {
      __name = 'Pool',
      _start = _start,
      close = close,
      open = open
    }

    local cb = function(err)
      if not _r.pool then
        _r.pool = inst
      end
      if _callback then
        local res = _callback(err, inst)
        close({noreply_wait = false})
        return res
      end
      return inst, err
    end

    return builder.connect(function(err, conn)
      if err then return cb(err) end
      _open = true
      table.insert(pool, conn)
      size = host.size or 12
      for i=2, size do
        table.insert(pool, (builder.connect()))
      end
      return cb()
    end)
  end
end

return m
