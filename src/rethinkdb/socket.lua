--- Interface to handle socket timeouts and recoverable errors.
-- @module rethinkdb.socket
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local errors = require'rethinkdb.errors'
local ssl = require('ssl')

local function socket(r, host, port, ssl_params, timeout)
  local function open()
    local raw_socket = r.socket()

    if not raw_socket then
      return nil
    end

    local function defer(err)
      if err then
        return nil, errors.ReQLDriverError(err)
      end
      return raw_socket
    end

    raw_socket:settimeout(timeout, 't')
    raw_socket:settimeout(timeout, 'b')

    local status, err = raw_socket:connect(host, port)

    if not status then
      if err == 'closed' then
        return defer(err)
      elseif err == 'wantread' then
        local recvt, _, sel_err = r.select({raw_socket}, nil, timeout)
        if sel_err == 'timeout' or not recvt[raw_socket] then
          return defer(err)
        end
      elseif err == 'timeout' or err == 'wantwrite' then
        local _, sendt, sel_err = r.select(nil, {raw_socket}, timeout)
        if sel_err == 'timeout' or not sendt[raw_socket] then
          return defer(err)
        end
      elseif err then
        return defer(err)
      end
    end

    if ssl_params then
      raw_socket = ssl.wrap(raw_socket, ssl_params)
      status = false
      while not status do
        status, err = raw_socket:dohandshake()
        if not status then
          if err == 'closed' then
            return defer(err)
          elseif err == 'timeout' or err == 'wantread' then
            local recvt, _, sel_err = r.select({raw_socket}, nil, timeout)
            if sel_err == 'timeout' or not recvt[raw_socket] then
              return defer(err)
            end
          elseif err == 'wantwrite' then
            local _, sendt, sel_err = r.select(nil, {raw_socket}, timeout)
            if sel_err == 'timeout' or not sendt[raw_socket] then
              return defer(err)
            end
          elseif err then
            return defer(err)
          end
        end
      end
    end

    return defer()
  end

  local raw_socket, init_err = open()

  if not raw_socket then
    return nil, init_err
  end

  local function shutdown()
    if not ngx and not ssl_params then  --luacheck: globals ngx
      raw_socket:shutdown()
    end
    raw_socket:close()
  end

  local inst = {r = r}

  function inst.send(...)
    if not raw_socket then return nil, errors.ReQLDriverError'closed' end
    local data = table.concat{...}
    local idx, err, err_idx = raw_socket:send(data)
    if idx == #data then
      return idx, ''
    end
    if err == 'closed' then
      raw_socket = nil
    elseif err == 'wantread' then
      local recvt, _, sel_err = r.select({raw_socket}, nil, timeout)
      if sel_err == 'timeout' or not recvt[raw_socket] then
        return nil, errors.ReQLDriverError(err)
      end
    elseif err == 'timeout' or err == 'wantwrite' then
      local _, sendt, sel_err = r.select(nil, {raw_socket}, timeout)
      if sel_err == 'timeout' or not sendt[raw_socket] then
        return nil, errors.ReQLDriverError(err)
      end
    elseif err then
      return nil, errors.ReQLDriverError(err)
    end
    idx = idx or err_idx
    return idx, string.sub(data, idx + 1)
  end

  function inst.close()
    local client = nil
    raw_socket, client = client, raw_socket

    shutdown(client)
  end

  function inst.recv(pat)
    local function defer(t, ...)
      if not t then
        inst.close()
        return nil, errors.ReQLDriverError(...)
      end
      return t, ...
    end
    local buf, err, partial = raw_socket:receive(pat)
    if buf then
      return defer(buf)
    end
    if err == 'timeout' and partial then
      return defer(partial)
    end
    if err == 'closed' then
      return defer(partial or '')
    elseif err == 'timeout' or err == 'wantread' then
      local recvt, _, sel_err = r.select({raw_socket}, nil, timeout)
      if sel_err == 'timeout' or not recvt[raw_socket] then
        return defer(nil, err)
      end
    elseif err == 'wantwrite' then
      local _, sendt, sel_err = r.select(nil, {raw_socket}, timeout)
      if sel_err == 'timeout' or not sendt[raw_socket] then
        return defer(nil, err)
      end
    elseif err then
      return defer(nil, err)
    end
    return defer(partial or '')
  end

  return inst
end

return socket
