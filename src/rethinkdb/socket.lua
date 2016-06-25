--- Interface to handle socket timeouts and recoverable errors.
-- @module rethinkdb.socket
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

  local inst = {r = r}

  function inst.send(...)
    local data = table.concat{...}
    local idx, err = raw_socket:send(data)
    if not idx then
      inst.close()
      return nil, err
    end
    if idx == #data then
      return idx
    end
    inst.close()
    return nil, 'incomplete write'
  end

  function inst.close()
    if not ngx and not ssl_params then  --luacheck: globals ngx
      raw_socket:shutdown()
    end
    raw_socket:close()
  end

  function inst.recv(pat)
    local buf, err = raw_socket:receive(pat)
    if not buf then
      inst.close()
      return nil, err
    end
    return buf
  end

  return inst
end

return socket
