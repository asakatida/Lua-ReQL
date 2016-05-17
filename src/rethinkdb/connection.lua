--- Interface to handle default connection construction.
-- @module rethinkdb.connection

local connection_instance = require'rethinkdb.connection_instance'
local current_protocol = require'rethinkdb.current_protocol'

local DEFAULT_HOST = 'localhost'
local DEFAULT_PORT = 28015
local DEFAULT_USER = 'admin'
local DEFAULT_AUTH_KEY = ''
local DEFAULT_TIMEOUT = 20 -- In seconds

return function(connection_opts, _proto_version)
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

  return {
    _start = _start,
    connect = connect,
    use = use
  }
end
