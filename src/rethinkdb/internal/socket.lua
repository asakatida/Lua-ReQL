--- Interface to handle socket timeouts and recoverable errors.
-- @module rethinkdb.internal.socket
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local ssl = require('ssl')

local function socket(r, host, port, ssl_params, timeout)
  local function open()
    local raw_socket = r.socket()

    if not raw_socket then
      return nil, 'error getting socket.'
    end

    local function defer(err)
      if err then
        return nil, err
      end
      return raw_socket
    end

    raw_socket:settimeout(timeout, 't')
    raw_socket:settimeout(timeout, 'b')

    local status, err = raw_socket:connect(host, port)

    if not status then
      return defer(err)
    end

    if ssl_params then
      raw_socket = ssl.wrap(raw_socket, ssl_params)
      status = false
      while not status do
        status, err = raw_socket:dohandshake()
        if not status then
          return defer(err)
        end
      end
    end

    return defer()
  end

  local raw_socket, init_err = open()

  if not raw_socket then
    return nil, init_err
  end

  local socket_inst = {r = r}

  function socket_inst.send(...)
    local data = table.concat{...}
    local idx, err = raw_socket:send(data)
    if idx == #data then
      return idx
    end
    socket_inst.close()
    if not idx then
      return nil, err
    end
    return nil, 'incomplete write'
  end

  function socket_inst.close()
    if not ngx and not ssl_params then  --luacheck: globals ngx
      raw_socket:shutdown()
    end
    raw_socket:close()
  end

  function socket_inst.recv(pat)
    local buf, err, partial = raw_socket:receive(pat)
    if err == 'timeout' and partial then
      if string.len(partial) > 0 then
        return partial
      end
      return nil, err
    end
    if not buf then
      socket_inst.close()
      return nil, err
    end
    return buf
  end

  return socket_inst
end

return socket
