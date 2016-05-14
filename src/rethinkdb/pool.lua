local Connection = require'rethinkdb.connection'

return function(host, _callback)
  local size
  local _open = false
  local key = 1
  local pool = {}
  local builder = Connection(host)

  local function _start(term, callback, opts)
    if opts.conn then
      local good_conn = pool[opts.conn]
      if good_conn then
        return good_conn._start(term, callback, opts)
      end
    end
    local good_conn = pool[key]
    if good_conn == nil then
      key = 1
      good_conn = next(pool)
    end
    if not good_conn.open() then
      pool[key] = good_conn.connect()
    end
    key = key + 1
    for i=1, size do
      if not pool[i] then pool[i] = builder.connect() end
      local conn = pool[i]
      if not conn.open() then
        conn.connect()
        pool[i] = conn
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

  local function use(db)
    for i=1, size do
      local conn = pool[i]
      if conn then conn.use(db) end
    end
  end

  local inst = {
    _start = _start,
    close = close,
    open = open,
    use = use
  }

  local cb = function(err)
    --[[ TODO
    if not r.pool then
      r.pool = inst
    end]]
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
    for _=2, size do
      table.insert(pool, (builder.connect()))
    end
    return cb()
  end)
end
