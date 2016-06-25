--- Main interface combining public modules in an export table.
-- @module rethinkdb
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016
-- @alias r

local utilities = require'rethinkdb.utilities'

local ast = require'rethinkdb.ast'
local connection_instance = require'rethinkdb.connection_instance'
local current_handshake = require'rethinkdb.current_handshake'
local handshake = require'rethinkdb.handshake'
local int_to_bytes = require'rethinkdb.int_to_bytes'

local v = require('rethinkdb.semver')

local DEFAULT_HOST = 'localhost'
local DEFAULT_PORT = 28015
local DEFAULT_USER = 'admin'
local DEFAULT_AUTH_KEY = ''
local DEFAULT_TIMEOUT = 0.1 -- In seconds

local function proto_V0_x(raw_socket, auth_key, magic)
  -- Initialize connection with magic number to validate version
  local size, send_err = raw_socket.send(
    magic,
    int_to_bytes(#auth_key, 4),
    auth_key,
    '\199\112\105\126'
  )
  if not size then
    return nil, send_err
  end

  -- Now we have to wait for a response from the server
  -- acknowledging the connection
  local message, err = raw_socket.get_success()

  if message then
    -- We're good, finish setting up the connection
    return true
  end
  return nil, err
end

local function new(options)
  options = options or {}

  -- r is both the main export table for the module
  -- and a function that wraps a native Lua value in a ReQL datum
  local r = {}

  r.b64 = utilities.b64(options)
  r.decode = utilities.decode(options)
  r.encode = utilities.encode(options)
  r.new = new
  r.proto_V1_0 = current_handshake
  r.r = r
  r.reql = ast
  r.select = utilities._select(options)
  r.socket = utilities.socket(options)
  r.unb64 = utilities.unb64(options)
  r.version = v'1.0.0'
  r._VERSION = r.version

  function r.connect(host, callback)
    if type(host) == 'function' then
      callback = host
      host = {}
    elseif type(host) == 'string' then
      host = {host = host}
    end
    return r.Connection(host).connect(callback)
  end

  --- Interface to handle default connection construction.
  function r.Connection(connection_opts)
    local auth_key = connection_opts.password or connection_opts.auth_key or DEFAULT_AUTH_KEY
    local db = connection_opts.db -- left nil if this is not set
    local host = connection_opts.host or DEFAULT_HOST
    local port = connection_opts.port or DEFAULT_PORT
    local proto_version = connection_opts.proto_version or current_handshake
    local ssl_params = connection_opts.ssl
    local timeout = connection_opts.timeout or DEFAULT_TIMEOUT
    local user = connection_opts.user or DEFAULT_USER

    local handshake_inst = handshake(auth_key, proto_version, user)

    local inst = {r = r}

    function inst.connect(callback)
      if callback then
        local function cb(err, conn)
          if err then
            return callback(err)
          end
          conn.use(db)
          return callback(nil, conn)
        end
        return connection_instance(
          inst.r,
          handshake_inst,
          host,
          port,
          ssl_params,
          timeout
        ).connect(cb)
      end

      local conn, err = connection_instance(
        inst.r,
        handshake_inst,
        host,
        port,
        ssl_params,
        timeout
      ).connect()
      if err then
        return nil, err
      end
      conn.use(db)
      return conn
    end

    function inst._start(term, callback, opts)
      local function cb(err, conn)
        if err then
          if callback then
            return callback(err)
          end
          return nil, err
        end
        conn.use(db)
        return conn._start(term, callback, opts)
      end
      return inst.connect(cb)
    end

    function inst.use(_db)
      db = _db
    end

    return inst
  end

  function r.proto_V0_3(raw_socket, auth_key)
    return proto_V0_x(raw_socket, auth_key, '\62\232\117\95')
  end

  function r.proto_V0_4(raw_socket, auth_key)
    return proto_V0_x(raw_socket, auth_key, '\32\45\12\64')
  end

  --- Helper to determine type of public interface.
  function r.type(obj)
    if type(obj) ~= 'table' then return nil end
    if not getmetatable(obj) then return nil end
    if type(obj.r) ~= 'table' then return nil end

    if type(obj.build) == 'function' and type(obj.compose) == 'function' then
      return 'reql'
    end

    if type(obj._start) == 'function' and type(obj.use) == 'function' then
      if type(obj.noreply_wait) == 'function' then
        return 'connection'
      end

      return 'connector'
    end

    if type(obj.each) == 'function' and type(obj.to_array) == 'function' then
      return 'cursor'
    end

    if type(obj.msg) == 'string' and type(obj.message) == 'function' then
      return 'error'
    end

    return nil
  end

  return r
end

return new()
