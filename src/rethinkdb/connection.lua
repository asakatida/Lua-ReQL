--- Interface to handle default connection construction.
-- @module rethinkdb.connection
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local connection_instance = require'rethinkdb.connection_instance'
local current_protocol = require'rethinkdb.current_protocol'

local DEFAULT_HOST = 'localhost'
local DEFAULT_PORT = 28015
local DEFAULT_USER = 'admin'
local DEFAULT_AUTH_KEY = ''
local DEFAULT_TIMEOUT = 20 -- In seconds

--- Interface to handle a pool of connections.
local function pool_instance(builder, size, _callback)
  local _open = false
  local key = 1
  local pool = {}

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
    if not good_conn.is_open() then
      pool[key] = good_conn.connect()
    end
    key = key + 1
    for i=1, size do
      if not pool[i] then pool[i] = builder.connect() end
      local conn = pool[i]
      if not conn.is_open() then
        conn.connect()
        pool[i] = conn
      end
    end
    return good_conn._start(term, callback, opts)
  end

  local function close(opts, callback)
    local err
    local function cb(e)
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
      if conn.is_open() then return true end
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

  local function cb(err)
    --[[ TODO
    if not r.pool then
      r.pool = inst
    end]]
    if _callback then
      local res = _callback(err, inst)
      close{noreply_wait = false}
      return res
    end
    return inst, err
  end

  local function on_connection(err, conn)
    if err then return cb(err) end
    _open = true
    table.insert(pool, conn)
    for _=2, size do
      table.insert(pool, (builder.connect()))
    end
    return cb()
  end

  return builder.connect(on_connection)
end

local function connection(connection_opts, _proto_version)
  local port = connection_opts.port or DEFAULT_PORT
  local db = connection_opts.db -- left nil if this is not set
  local auth_key = connection_opts.password or connection_opts.auth_key or DEFAULT_AUTH_KEY
  local user = connection_opts.user or DEFAULT_USER
  local timeout = connection_opts.timeout or DEFAULT_TIMEOUT
  local ssl_params = connection_opts.ssl
  local proto_version = _proto_version or current_protocol
  local host = connection_opts.host or DEFAULT_HOST
  local r = connection_opts.r or {}

  local function connect(callback)
    return connection_instance(
      r, auth_key, db, host, port, proto_version, ssl_params, timeout, user
      ).connect(callback)
  end

  local function _start(term, callback, opts)
    local function cb(err, conn)
      if err then
        if callback then
          return callback(err)
        end
        error(err.message())
      end
      return conn._start(term, callback, opts)
    end
    return connect(cb)
  end

  local function use(_db)
    db = _db
  end

  local inst = {
    _start = _start,
    connect = connect,
    use = use
  }

  local pool = connection_opts.pool

  if pool then
    local function pool_connect(callback)
      return pool_instance(inst, pool, callback)
    end

    inst.connect = pool_connect
  end

  return inst
end

return connection
