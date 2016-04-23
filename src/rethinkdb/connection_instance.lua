local bytes_to_int = require'rethinkdb.bytes_to_int'
local Cursor = require'rethinkdb.cursor'
local errors = require'rethinkdb.errors'
local int_to_bytes = require'rethinkdb.int_to_bytes'
local proto = require'rethinkdb.protodef'

local m = {}

function m.init(_r)
  return function(auth_key, db, host, port, proto_version, ssl_params, timeout, user)
    local raw_socket
    local outstanding_callbacks = {}
    local weight = 0
    local next_token = 1
    local buffer = ''

    local function weight_for_feed()
      weight = weight + 2
    end

    local function write_socket(token, query)
      if not raw_socket then return nil, 'closed' end
      local data = _r.encode(query)
      return raw_socket:send(
        int_to_bytes(token, 8) ..
        int_to_bytes(#data, 4) ..
        data
      )
    end

    local function continue_query(token)
      return write_socket(token, {proto.Query.CONTINUE})
    end

    local function del_query(token)
      -- This query is done, delete this cursor
      if not outstanding_callbacks[token] then return end
      if outstanding_callbacks[token].cursor then
        if outstanding_callbacks[token].cursor.type ~= 'finite' then
          weight = weight - 2
        end
        weight = weight - 1
      end
      outstanding_callbacks[token].cursor = nil
    end

    local function end_query(token)
      del_query(token)
      return write_socket(token, {proto.Query.STOP})
    end

    local function process_response(response, token)
      local cursor = outstanding_callbacks[token]
      if not cursor then
        -- Unexpected token
        return _r.logger('Unexpected token ' .. token .. '.')
      end
      local add_response = cursor.add_response
      cursor = cursor.cursor
      if cursor then
        return add_response(weight_for_feed, response)
      end
    end

    local instance = {
      __name = 'ConnInstance',
      open = function()
        if raw_socket then
          return true
        end
        return false
      end,
      use = function(_db)
        db = _db
      end
    }

    local function get_response(reqest_token)
      local response_length = 0
      local token = 0
      local buf, err, partial
      -- Buffer data, execute return results if need be
      while true do
        buf, err, partial = raw_socket:receive(
          math.max(12, response_length)
        )
        buf = buf or partial
        if (not buf) and err then
          instance.close({noreply_wait = false})
          return process_response(
            {
              t = proto.Response.CLIENT_ERROR,
              r = {'connection returned: ' .. err},
              b = {}
            },
            reqest_token
          )
        end
        buffer = buffer .. buf
        if response_length > 0 then
          if #(buffer) >= response_length then
            local response_buffer = string.sub(buffer, 1, response_length)
            buffer = string.sub(buffer, response_length + 1)
            response_length = 0
            continue_query(token)
            process_response(_r.decode(response_buffer), token)
            if token == reqest_token then return end
          end
        else
          if #(buffer) >= 12 then
            token = bytes_to_int(buffer:sub(1, 8))
            response_length = bytes_to_int(buffer:sub(9, 12))
            buffer = buffer:sub(13)
          end
        end
      end
    end

    local function make_cursor(token, opts, term)
      local cursor, add_response = Cursor(
         del_query, end_query, get_response, token, opts or {}, term)

      -- Save cursor

      outstanding_callbacks[token] = {
        cursor = cursor,
        add_response = add_response
      }

      return cursor
    end

    function instance._start(term, callback, opts)
      local cb = function(err, cur)
        local res
        if type(callback) == 'function' then
          res = callback(err, cur)
        else
          if err then
            return _r.logger(err.message)
          end
        end
        cur.close()
        return res
      end
      if not raw_socket then
        return cb(errors.ReQLDriverError('Connection is closed.'))
      end

      -- Assign token
      local token = next_token
      next_token = next_token + 1
      weight = weight + 1

      -- Set global options
      local global_opts = {}

      for k, v in pairs(opts) do
        global_opts[k] = _r(v):build()
      end

      if opts.db then
        global_opts.db = _r(opts.db):db():build()
      elseif db then
        global_opts.db = _r(db):db():build()
      end

      if type(callback) ~= 'function' then
        global_opts.noreply = true
      end

      -- Construct query
      local query = {proto.Query.START, term:build(), global_opts}

      local _, err = write_socket(token, query)

      if err then
        instance.close({noreply_wait = false}, function(_err)
          return cb(_err or errors.ReQLDriverError('Connection is closed.'))
        end)
      end

      return cb(nil, make_cursor(token, opts, term))
    end

    function instance.close(opts_or_callback, callback)
      local opts = {}
      if callback then
        if type(opts_or_callback) ~= 'table' then
          return error('First argument to two-argument `close` must be a table.')
        end
        opts = opts_or_callback
      elseif type(opts_or_callback) == 'table' then
        opts = opts_or_callback
      elseif type(opts_or_callback) == 'function' then
        callback = opts_or_callback
      end

      local function cb(err)
        if raw_socket then
          if ngx == nil and ssl_params == nil then
            raw_socket:shutdown()
          end
          raw_socket:close()
          raw_socket = nil
        end
        if callback then
          return callback(err)
        end
        return nil, err
      end

      local noreply_wait = (opts.noreply_wait ~= false) and raw_socket

      if noreply_wait then
        return noreply_wait(cb)
      end
      return cb()
    end

    function instance.connect(callback)
      return instance.close({noreply_wait = false}, function()
        raw_socket = _r.socket()
        raw_socket:settimeout(timeout)

        local status, err = raw_socket:connect(host, port)

        if ssl_params then
          raw_socket = _r.lib_ssl.wrap(raw_socket, ssl_params)
          status = false
          while not status do
            status, err = raw_socket:dohandshake()
            if err == "timeout" or err == "wantread" then
              _r.select({raw_socket}, nil)
            elseif err == "wantwrite" then
              _r.select(nil, {raw_socket})
            else
              _r.logger(err)
            end
          end
        end

        raw_socket, buffer, err = proto_version(raw_socket, auth_key, user)

        err = errors.ReQLDriverError('Could not connect to ' .. host .. ':' .. port .. '.\n' .. err)

        if callback then
          local res = callback(err, instance)
          instance.close({noreply_wait = false})
          return res
        end
        return instance, err
      end)
    end

    function instance.noreply_wait(callback)
      local cb = function(_err, _cur)
        if _cur then
          return _cur.next(function(err)
            weight = 0
            for token, cur in pairs(outstanding_callbacks) do
              if cur.cursor then
                weight = weight + 3
              else
                outstanding_callbacks[token] = nil
              end
            end
            return callback(err)
          end)
        end
        return callback(_err)
      end
      if not raw_socket then
        return cb(errors.ReQLDriverError('Connection is closed.'))
      end

      -- Assign token
      local token = next_token
      next_token = next_token + 1

      local cursor = make_cursor(token)

      -- Construct query
      write_socket(token, {proto.Query.NOREPLY_WAIT})

      return cb(nil, cursor)
    end

    function instance.reconnect(opts_or_callback, callback)
      local opts = {}
      if callback or not type(opts_or_callback) == 'function' then
        opts = opts_or_callback
      else
        callback = opts_or_callback
      end
      return instance.close(opts, function()
        return instance.connect(callback)
      end)
    end

    function instance.server()
      local cb = function(err, cur)
      end
      if not raw_socket then
        return cb(errors.ReQLDriverError('Connection is closed.'))
      end

      -- Assign token
      local token = next_token
      next_token = next_token + 1

      local cursor = make_cursor(token)

      -- Construct query
      write_socket(token, {proto.Query.SERVER_INFO})

      return cb(nil, cursor)
    end

    return instance
  end
end

return m
