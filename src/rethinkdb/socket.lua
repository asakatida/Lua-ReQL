--- Interface to handle socket timeouts and recoverable errors.
-- @module rethinkdb.socket
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local bytes_to_int = require'rethinkdb.bytes_to_int'
local errors = require'rethinkdb.errors'
local ssl = require('ssl')

local function receive(connection, pattern)
  connection:timeout(0)
  local s, status = connection:receive(pattern)
  if status == 'timeout' then
    coroutine.yield(connection)
  end
  return s, status
end

local function download(connection)
  while true do
    local s, status = receive(connection)
    if status == 'closed' then break end
  end
  connection:close()
end

local function get(threads, connection)
  local co = coroutine.create(function ()
    download(connection)
  end)
  table.insert(threads, co)
end

local function dispatcher(r, threads)
  local n = table.getn(threads)
  if n == 0 then return end
  local connections = {}
  for i=1, n do
    local status, res = coroutine.resume(threads[i])
    if not res then
      table.remove(threads, i)
      break
    else
      table.insert(connections, res)
    end
  end
  if table.getn(connections) == n then
    r.select(connections)
  end
end

local threads = {}

local function socket(r, host, port, ssl_params, timeout)
  local raw_socket = nil

  local function shutdown(client)
    if client then
      if not ngx and not ssl_params then  --luacheck: globals ngx
        client:shutdown()
      end
      client:close()
    end
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

  function inst.is_open()
    return raw_socket and true or false
  end

  function inst.open()
    local client = r.socket()
    shutdown(raw_socket)
    raw_socket = nil
    local function defer(err)
      if err then
        shutdown(client)
        return errors.ReQLDriverError(err)
      else
        client:settimeout(0, 't')
        client:settimeout(0, 'b')
        raw_socket, client = client, raw_socket
      end
    end
    client:settimeout(timeout, 't')
    client:settimeout(timeout, 'b')

    local status, err = client:connect(host, port)

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
      client = ssl.wrap(client, ssl_params)
      status = false
      while not status do
        status, err = client:dohandshake()
        if not status then
          if err == 'closed' then
            return defer(err)
          elseif err == 'timeout' or err == 'wantread' then
            local recvt, _, sel_err = r.select({client}, nil, timeout)
            if sel_err == 'timeout' or not recvt[client] then
              return defer(err)
            end
          elseif err == 'wantwrite' then
            local _, sendt, sel_err = r.select(nil, {client}, timeout)
            if sel_err == 'timeout' or not sendt[client] then
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

  local function recv(pat)
    if not raw_socket then return nil, errors.ReQLDriverError'closed' end
    local function defer(t, ...)
      if not t then
        inst.close()
        return nil, errors.ReQLDriverError(...)
      end
      raw_socket:settimeout(0, 't')
      raw_socket:settimeout(0, 'b')
      return t, ...
    end
    raw_socket:settimeout(timeout, 't')
    raw_socket:settimeout(timeout, 'b')
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

  function inst.get_success()
    local buffer = ''
    while string.len(buffer) < 8 do
      local buf, err = recv(8 - string.len(buffer))
      if err then
        return nil, err
      end
      buffer = buffer .. buf
    end
    if buffer == 'SUCCESS\0' then
      return buffer
    end
    return nil, buffer .. ((recv'*a') or '')
  end

  function inst.decode_message(buffer)
    local i = nil
    while not i do
      local buf, err = recv(32)
      if err then
        return nil, err, ''
      end
      buffer = buffer .. buf
      i = string.find(buffer, '\0')
    end

    local message = string.sub(buffer, 1, i - 1)

    local response = r.decode(message)

    if not response then
      return nil, errors.ReQLDriverError(message), ''
    end

    return response, nil, string.sub(buffer, i + 1)
  end

  function inst.query_response(buffer)
    while string.len(buffer) < 12 do
      local buf, err = recv(12 - string.len(buffer))
      if err then
        return nil, err, ''
      end
      buffer = buffer .. buf
    end
    local token = bytes_to_int(string.sub(buffer, 1, 8))
    local response_length = bytes_to_int(string.sub(buffer, 9, 12))
    buffer = string.sub(buffer, 13)
    while string.len(buffer) < response_length do
      local buf, err = recv(response_length - string.len(buffer))
      if err then
        return nil, err, ''
      end
      buffer = buffer .. buf
    end
    return token,
           string.sub(buffer, 1, response_length),
           string.sub(buffer, response_length + 1)
  end

  return inst
end

return socket
