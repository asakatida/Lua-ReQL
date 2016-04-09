local class = require'rethinkdb.class'
local convert_pseudotype = require'rethinkdb.convert_pseudotype'
local Cursor = require'rethinkdb.cursor'
local errors = require'rethinkdb.errors'
local proto = require'rethinkdb.protodef'

-- r is both the main export table for the module
-- and a function that wraps a native Lua value in a ReQL datum
local r = {
  is_instance = require'rethinkdb.is_instance'
}

r._lib_ssl = require('ssl')

local ast = require'rethinkdb.ast'.init(r)

function r._logger(err)
  if r.logger then
    r.logger(err)
  elseif type(err) == 'string' then
    error(err)
  elseif type(err) == 'table' and err.msg then
    error(err.msg)
  else
    error('Unknown error type from driver')
  end
end

function r._unb64(data)
  if r.unb64 then
    return r.unb64(data)
  elseif not r._lib_mime then
    r._lib_mime = require('mime')
  end
  r.unb64 = r._lib_mime.unb64
  return r._lib_mime.unb64(data)
end

function r._b64(data)
  if r.b64 then
    return r.b64(data)
  elseif not r._lib_mime then
    r._lib_mime = require('mime')
  end
  r.b64 = r._lib_mime.b64
  return r._lib_mime.b64(data)
end

function r._encode(data)
  if r.encode then
    return r.encode(data)
  elseif r.json_parser then
    r.encode = r.json_parser.encode
    return r.json_parser.encode(data)
  elseif not r._lib_json then
    if ngx == nil then
      r._lib_json = require('json')
    else
      r._lib_json = require('cjson')
    end
  end
  r.encode = r._lib_json.encode
  r.json_parser = r._lib_json
  return r._lib_json.encode(data)
end

function r._decode(buffer)
  if r.decode then
    return r.decode(buffer)
  elseif r.json_parser then
    r.decode = r.json_parser.decode
    return r.json_parser.decode(buffer)
  elseif not r._lib_json then
    if ngx == nil then
      r._lib_json = require('json')
    else
      r._lib_json = require('cjson')
    end
  end
  r.decode = r._lib_json.decode
  r.json_parser = r._lib_json
  return r._lib_json.decode(buffer)
end

function r._socket()
  if r.socket then
    return r.socket()
  elseif not r._lib_socket then
    if ngx == nil then
      r._lib_socket = require('socket')
    else
      r._lib_socket = ngx.socket
    end
  end
  r.socket = r._lib_socket.tcp
  return r._lib_socket.tcp()
end

setmetatable(r, {
  __call = function(cls, val, nesting_depth)
    if nesting_depth == nil then
      nesting_depth = 20
    end
    if type(nesting_depth) ~= 'number' then
      return r._logger('Second argument to `r(val, nesting_depth)` must be a number.')
    end
    if nesting_depth <= 0 then
      return r._logger('Nesting depth limit exceeded')
    end
    if r.is_instance(val, 'ReQLOp') and type(val.build) == 'function' then
      return val
    end
    if type(val) == 'function' then
      return ast.FUNC({}, val)
    end
    if type(val) == 'table' then
      local array = true
      for k, v in pairs(val) do
        if type(k) ~= 'number' then array = false end
        val[k] = r(v, nesting_depth - 1)
      end
      if array then
        return ast.MAKE_ARRAY({}, unpack(val))
      end
      return ast.MAKE_OBJ(val)
    end
    if type(val) == 'userdata' then
      val = pcall(tostring, val)
      r._logger('Found userdata inserting "' .. val .. '" into query')
      return ast.DATUMTERM(val)
    end
    if type(val) == 'thread' then
      val = pcall(tostring, val)
      r._logger('Cannot insert thread object into query ' .. val)
      return nil
    end
    return ast.DATUMTERM(val)
  end
})

function r.connect(host_or_callback, callback)
  return r.Connection():connect(host_or_callback, callback)
end

r.Connection = class(
  'Connection',
  {
    connect = function(self, host_or_callback, callback)
      local host = {}
      if type(host_or_callback) == 'function' then
        callback = host_or_callback
      elseif type(host_or_callback) == 'string' then
        host = {host = host_or_callback}
      elseif host_or_callback then
        host = host_or_callback
      end
      self.weight = 0
      self.host = host.host or self.DEFAULT_HOST
      self.port = host.port or self.DEFAULT_PORT
      self.db = host.db -- left nil if this is not set
      self.auth_key = host.auth_key or self.DEFAULT_AUTH_KEY
      self.timeout = host.timeout or self.DEFAULT_TIMEOUT
      self.ssl_params = host.ssl
      self.outstanding_callbacks = {}
      self.next_token = 1
      self.buffer = ''
      if self.raw_socket then
        self:close({noreply_wait = false})
      end
      return self:_connect(callback)
    end,
    _connect = function(self, callback)
      local cb = function(err, conn)
        if callback then
          local res = callback(err, conn)
          conn:close({noreply_wait = false})
          return res
        end
        return conn, err
      end
      self.raw_socket = r._socket()
      self.raw_socket:settimeout(self.timeout)
      local status, err = self.raw_socket:connect(self.host, self.port)
      if status then
        if self.ssl_params then
        end
        local buf, err, partial
        -- Initialize connection with magic number to validate version
        self.raw_socket:send(
          '\32\45\12\64' ..
          self.int_to_bytes(#(self.auth_key), 4) ..
          self.auth_key ..
          '\199\112\105\126'
        )

        -- Now we have to wait for a response from the server
        -- acknowledging the connection
        while 1 do
          buf, err, partial = self.raw_socket:receive(8)
          buf = buf or partial
          if not buf then
            return cb(errors.ReQLDriverError('Server dropped connection with message:  \'' .. status_str .. '\'\n' .. err))
          end
          self.buffer = self.buffer .. buf
          i, j = buf:find('\0')
          if i then
            local status_str = self.buffer:sub(1, i - 1)
            self.buffer = self.buffer:sub(i + 1)
            if status_str == 'SUCCESS' then
              -- We're good, finish setting up the connection
              return cb(nil, self)
            end
            return cb(errors.ReQLDriverError('Server dropped connection with message: \'' .. status_str .. '\''))
          end
        end
      end
      return cb(errors.ReQLDriverError('Could not connect to ' .. self.host .. ':' .. self.port .. '.\n' .. err))
    end,
    _wrap = function(self, callback)
      self.raw_socket = r._lib_ssl.wrap(self.raw_socket, self.ssl_params)
      self.raw_socket:dohandshake()
    end,
    DEFAULT_HOST = 'localhost',
    DEFAULT_PORT = 28015,
    DEFAULT_AUTH_KEY = '',
    DEFAULT_TIMEOUT = 20, -- In seconds
    _get_response = function(self, reqest_token)
      local response_length = 0
      local token = 0
      local buf, err, partial
      -- Buffer data, execute return results if need be
      while true do
        buf, err, partial = self.raw_socket:receive(
          math.max(12, response_length)
        )
        buf = buf or partial
        if (not buf) and err then
          self:close({noreply_wait = false})
          return self:_process_response(
            {
              t = proto.Response.CLIENT_ERROR,
              r = {'connection returned: ' .. err},
              b = {}
            },
            reqest_token
          )
        end
        self.buffer = self.buffer .. buf
        if response_length > 0 then
          if #(self.buffer) >= response_length then
            local response_buffer = string.sub(self.buffer, 1, response_length)
            self.buffer = string.sub(self.buffer, response_length + 1)
            response_length = 0
            self:_continue_query(token)
            self:_process_response(r._decode(response_buffer), token)
            if token == reqest_token then return end
          end
        else
          if #(self.buffer) >= 12 then
            token = self.bytes_to_int(self.buffer:sub(1, 8))
            response_length = self.bytes_to_int(self.buffer:sub(9, 12))
            self.buffer = self.buffer:sub(13)
          end
        end
      end
    end,
    _del_query = function(self, token)
      -- This query is done, delete this cursor
      if not self.outstanding_callbacks[token] then return end
      if self.outstanding_callbacks[token].cursor then
        if self.outstanding_callbacks[token].cursor._type ~= 'finite' then
          self.weight = self.weight - 2
        end
        self.weight = self.weight - 1
      end
      self.outstanding_callbacks[token].cursor = nil
    end,
    _process_response = function(self, response, token)
      local cursor = self.outstanding_callbacks[token]
      if not cursor then
        -- Unexpected token
        return r._logger('Unexpected token ' .. token .. '.')
      end
      cursor = cursor.cursor
      if cursor then
        return cursor:_add_response(response)
      end
    end,
    close = function(self, opts_or_callback, callback)
      local opts = {}
      local cb
      if callback then
        if type(opts_or_callback) ~= 'table' then
          return error('First argument to two-argument `close` must be a table.')
        end
        opts = opts_or_callback
        cb = callback
      elseif type(opts_or_callback) == 'table' then
        opts = opts_or_callback
      elseif type(opts_or_callback) == 'function' then
        cb = opts_or_callback
      end

      function wrapped_cb(err)
        if self.raw_socket then
          if ngx == nil then
            self.raw_socket:shutdown()
          end
          self.raw_socket:close()
          self.raw_socket = nil
        end
        if cb then
          return cb(err)
        end
        return nil, err
      end

      local noreply_wait = (opts.noreply_wait ~= false) and self:open()

      if noreply_wait then
        return self:noreply_wait(wrapped_cb)
      end
      return wrapped_cb()
    end,
    open = function(self)
      if self.raw_socket then
        return true
      end
      return false
    end,
    noreply_wait = function(self, callback)
      local cb = function(err, cur)
        if cur then
          return cur:next(function(err)
            self.weight = 0
            for token, cur in pairs(self.outstanding_callbacks) do
              if cur.cursor then
                self.weight = self.weight + 3
              else
                self.outstanding_callbacks[token] = nil
              end
            end
            return callback(err)
          end)
        end
        return callback(err)
      end
      if not self:open() then
        return cb(errors.ReQLDriverError('Connection is closed.'))
      end

      -- Assign token
      local token = self.next_token
      self.next_token = self.next_token + 1

      -- Save cursor
      local cursor = Cursor(self, token, {})

      -- Save cursor
      self.outstanding_callbacks[token] = {cursor = cursor}

      -- Construct query
      self:_write_socket(token, {proto.Query.NOREPLY_WAIT})

      return cb(nil, cursor)
    end,
    reconnect = function(self, opts_or_callback, callback)
      local opts = {}
      if callback or not type(opts_or_callback) == 'function' then
        opts = opts_or_callback
      else
        callback = opts_or_callback
      end
      return self:close(opts, function()
        return self:_connect(callback)
      end)
    end,
    use = function(self, db)
      self.db = db
    end,
    _start = function(self, term, callback, opts)
      local cb = function(err, cur)
        local res
        if type(callback) == 'function' then
          res = callback(err, cur)
        else
          if err then
            return r._logger(err.message)
          end
        end
        cur:close()
        return res
      end
      if not self:open() then
        return cb(errors.ReQLDriverError('Connection is closed.'))
      end

      -- Assign token
      local token = self.next_token
      self.next_token = self.next_token + 1
      self.weight = self.weight + 1

      -- Set global options
      local global_opts = {}

      for k, v in pairs(opts) do
        global_opts[k] = r(v):build()
      end

      if opts.db then
        global_opts.db = r.db(opts.db):build()
      elseif self.db then
        global_opts.db = r.db(self.db):build()
      end

      if type(callback) ~= 'function' then
        global_opts.noreply = true
      end

      -- Construct query
      local query = {proto.Query.START, term:build(), global_opts}

      local idx, err = self:_write_socket(token, query)
      if err then
        self:close({noreply_wait = false}, function(err)
          if err then return cb(err) end
          return cb(errors.ReQLDriverError('Connection is closed.'))
        end)
      end
      local cursor = Cursor(self, token, opts, term)
      -- Save cursor
      self.outstanding_callbacks[token] = {cursor = cursor}
      return cb(nil, cursor)
    end,
    _continue_query = function(self, token)
      self:_write_socket(token, {proto.Query.CONTINUE})
    end,
    _end_query = function(self, token)
      self:_del_query(token)
      self:_write_socket(token, {proto.Query.STOP})
    end,
    _write_socket = function(self, token, query)
      if not self.raw_socket then return nil, 'closed' end
      local data = r._encode(query)
      return self.raw_socket:send(
        self.int_to_bytes(token, 8) ..
        self.int_to_bytes(#data, 4) ..
        data
      )
    end,
    bytes_to_int = function(str)
      local t = {str:byte(1,-1)}
      local n = 0
      for k=1,#t do
        n = n + t[k] * 2 ^ ((k - 1) * 8)
      end
      return n
    end,
    int_to_bytes = function(num, bytes)
      local res = {}
      local mul = 0
      for k = bytes, 1, -1 do
        local den = 2 ^ (8 * (k - 1))
        res[k] = math.floor(num / den)
        num = math.fmod(num, den)
      end
      return string.char(unpack(res))
    end
  }
)

r.pool = class(
  'Pool',
  {
    __init = function(self, host, callback)
      local cb = function(err, pool)
        if not r._pool then
          r._pool = pool
        end
        if callback then
          local res = callback(err, pool)
          pool:close({noreply_wait = false})
          return res
        end
        return pool, err
      end
      self._open = false
      return r.connect(host, function(err, conn)
        if err then return cb(err) end
        self._open = true
        self.pool = {conn}
        self.size = host.size or 12
        self.host = host
        for i=2, self.size do
          table.insert(self.pool, (r.connect(host)))
        end
        return cb(nil, self)
      end)
    end,
    close = function(self, opts, callback)
      local err
      local cb = function(e)
        if e then
          err = e
        end
      end
      for _, conn in pairs(self.pool) do
        conn:close(opts, cb)
      end
      self._open = false
      if callback then return callback(err) end
    end,
    open = function(self)
      if not self._open then return false end
      for _, conn in ipairs(self.pool) do
        if conn:open() then return true end
      end
      self._open = false
      return false
    end,
    _start = function(self, term, callback, opts)
      local weight = math.huge
      if opts.conn then
        local good_conn = self.pool[opts.conn]
        if good_conn then
          return good_conn:_start(term, callback, opts)
        end
      end
      local good_conn
      for i=1, self.size do
        if not self.pool[i] then self.pool[i] = r.connect(self.host) end
        local conn = self.pool[i]
        if not conn:open() then
          conn:reconnect()
          self.pool[i] = conn
        end
        if conn.weight < weight then
          good_conn = conn
          weight = conn.weight
        end
      end
      return good_conn:_start(term, callback, opts)
    end
  }
)

-- Export all names defined on r
return r
