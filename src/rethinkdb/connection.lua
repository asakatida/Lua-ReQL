local m = {}

local DEFAULT_HOST = 'localhost'
local DEFAULT_PORT = 28015
local DEFAULT_USER = 'admin'
local DEFAULT_AUTH_KEY = ''
local DEFAULT_TIMEOUT = 20 -- In seconds

function m.init(_r)
  local current_protocol = require'rethinkdb.current_protocol'.init(_r)
  local instance = require'rethinkdb.connection_instance'.init(_r)

  return function(opts, _proto_version)
    local port = opts.port or DEFAULT_PORT
    local db = opts.db -- left nil if this is not set
    local auth_key = opts.password or opts.auth_key or DEFAULT_AUTH_KEY
    local user = opts.user or DEFAULT_USER
    local timeout = opts.timeout or DEFAULT_TIMEOUT
    local ssl_params = opts.ssl
    local proto_version = _proto_version or current_protocol
    local host = opts.host or DEFAULT_HOST

    local function connect(callback)
      return instance(
        auth_key, db, host, port, proto_version, ssl_params, timeout, user
        ).connect(callback)
    end

    local factory = {
      __name = 'Connection',
      connect = connect
    }

    function factory._start(term, callback, opts)
      return connect()._start(term, callback, opts)
    end

    function factory.use(_db)
      db = _db
    end

    return factory
  end
end

return m
