local connection_instance = require'rethinkdb.connection_instance'
local current_protocol = require'rethinkdb.current_protocol'

local DEFAULT_HOST = 'localhost'
local DEFAULT_PORT = 28015
local DEFAULT_USER = 'admin'
local DEFAULT_AUTH_KEY = ''
local DEFAULT_TIMEOUT = 20 -- In seconds

return function(opts, _proto_version)
  local port = opts.port or DEFAULT_PORT
  local db = opts.db -- left nil if this is not set
  local auth_key = opts.password or opts.auth_key or DEFAULT_AUTH_KEY
  local user = opts.user or DEFAULT_USER
  local timeout = opts.timeout or DEFAULT_TIMEOUT
  local ssl_params = opts.ssl
  local proto_version = _proto_version or current_protocol
  local host = opts.host or DEFAULT_HOST
  local r = opts.r or {}

  local function connect(callback)
    return connection_instance(
      r, auth_key, db, host, port, proto_version, ssl_params, timeout, user
      ).connect(callback)
  end

  return {
    _start = function(...)
      return connect()._start(...)
    end,
    connect = connect,
    use = function(_db)
      db = _db
    end
  }
end
