local instance = require'rethinkdb.connection_instance'

local m = {}

local DEFAULT_HOST = 'localhost'
local DEFAULT_PORT = 28015
local DEFAULT_USER = 'admin'
local DEFAULT_AUTH_KEY = ''
local DEFAULT_TIMEOUT = 20 -- In seconds

function m.init(r, _r)
  instance = instance.init(r, _r)

  return function(host, proto_version)

    local port = host.port or DEFAULT_PORT
    local db = host.db -- left nil if this is not set
    local auth_key = host.password or host.auth_key or DEFAULT_AUTH_KEY
    local user = host.user or DEFAULT_USER
    local timeout = host.timeout or DEFAULT_TIMEOUT
    local ssl_params = host.ssl
    local proto_version = proto_version or r.proto_V1_0
    host = host.host or DEFAULT_HOST

    function connect(callback)
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
