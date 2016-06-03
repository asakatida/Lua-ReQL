--- Interface to handle socket timeouts and recoverable errors.
-- @module rethinkdb.socket
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local utilities = require'rethinkdb.utilities'

local errors = require'rethinkdb.errors'
local ssl = require('ssl')

local decode = utilities.decode
local _socket = utilities.socket
local _select = utilities._select

local function socket(r, host, port, ssl_params, timeout)
  local raw_socket = nil

  local function suppress_read_error(client, err)
    if err == 'closed' then
      raw_socket = nil
    elseif err == 'timeout' or err == 'wantread' then
      local recvt, _, sel_err = _select(r, {client}, nil, timeout)
      if sel_err == 'timeout' or not recvt[client] then
        return err
      end
    elseif err == 'wantwrite' then
      local _, sendt, sel_err = _select(r, nil, {client}, timeout)
      if sel_err == 'timeout' or not sendt[client] then
        return err
      end
    else
      return err
    end
  end

  local function suppress_write_error(client, err)
    if err == 'closed' then
      raw_socket = nil
    elseif err == 'wantread' then
      local recvt, _, sel_err = _select(r, {client}, nil, timeout)
      if sel_err == 'timeout' or not recvt[client] then
        return err
      end
    elseif err == 'timeout' or err == 'wantwrite' then
      local _, sendt, sel_err = _select(r, nil, {client}, timeout)
      if sel_err == 'timeout' or not sendt[client] then
        return err
      end
    else
      return err
    end
  end

  local function shutdown(client)
    if client then
      if ngx == nil and ssl_params == nil then  --luacheck: globals ngx
        client:shutdown()
      end
      client:close()
    end
  end

  local inst = {}

  function inst.close()
    local client = nil
    raw_socket, client = client, raw_socket

    shutdown(client)
  end

  function inst.is_open()
    return raw_socket and true or false
  end

  function inst.open()
    local client = _socket(r)
    client:settimeout(0)

    local status, err = client:connect(host, port)

    if not status and suppress_write_error(client, err) then
      return nil, errors.ReQLDriverError(err)
    end

    if ssl_params then
      client = ssl.wrap(client, ssl_params)
      status = false
      while not status do
        status, err = client:dohandshake()
        if suppress_read_error(client, err) then
          return nil, errors.ReQLDriverError(err)
        end
      end
    end

    raw_socket, client = client, raw_socket

    shutdown(client)
  end

  function inst.recv()
    if not raw_socket then return nil, errors.ReQLDriverError'closed' end
    local buf, err, partial = raw_socket:receive'*a'
    if buf then
      return buf
    end
    if err == 'timeout' and partial then
      return partial
    end
    if suppress_read_error(raw_socket, err) then
      return nil, errors.ReQLDriverError(err)
    end
    return partial or ''
  end

  function inst.send(...)
    if not raw_socket then return nil, errors.ReQLDriverError'closed' end
    local data = table.concat{...}
    local idx, err, err_idx = raw_socket:send(data)
    local size = #data
    if idx == size then
      return idx, size
    end
    if suppress_write_error(raw_socket, err) then
      return nil, errors.ReQLDriverError(err)
    end
    return err_idx, size
  end

  function inst.get_message(buffer)
    local i = nil
    while not i do
      local buf, err = inst.recv()
      if not buf then
        return nil, errors.ReQLDriverError(err)
      end
      buffer = buffer .. buf
      i = string.find(buffer, '\0')
    end

    local message = string.sub(buffer, 1, i - 1)
    buffer = string.sub(buffer, i + 1)
    return message, buffer
  end

  function inst.decode_message(buffer)
    local message
    message, buffer = inst.get_message(buffer)

    if message == nil then
      return nil, errors.ReQLDriverError(buffer)
    end

    local success, response = decode(r, message)

    if not success then
      return nil, errors.ReQLDriverError(response)
    end

    return response, buffer
  end

  return inst
end

return socket
