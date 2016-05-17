--- Interface to handle socket timeouts and recoverable errors.
-- @module rethinkdb.socket

local _r = require'rethinkdb.utilities'

local ssl = require('ssl')

return function(r, host, port, ssl_params, timeout)
  local raw_socket

  local function suppress_read_error(socket, err)
    if err == 'closed' then
      raw_socket = nil
    elseif err == 'timeout' or err == 'wantread' then
      local recvt, _, sel_err = _r.select(r, {socket}, nil, timeout)
      if sel_err == 'timeout' or not recvt[socket] then
        return err
      end
    elseif err == 'wantwrite' then
      local _, sendt, sel_err = _r.select(r, nil, {socket}, timeout)
      if sel_err == 'timeout' or not sendt[socket] then
        return err
      end
    else
      return err
    end
  end

  local function suppress_write_error(socket, err)
    if err == 'closed' then
      raw_socket = nil
    elseif err == 'wantread' then
      local recvt, _, sel_err = _r.select(r, {socket}, nil, timeout)
      if sel_err == 'timeout' or not recvt[socket] then
        return err
      end
    elseif err == 'timeout' or err == 'wantwrite' then
      local _, sendt, sel_err = _r.select(r, nil, {socket}, timeout)
      if sel_err == 'timeout' or not sendt[socket] then
        return err
      end
    else
      return err
    end
  end

  local function shutdown(socket)
    if socket then
      if ngx == nil and ssl_params == nil then
        socket:shutdown()
      end
      socket:close()
    end
  end

  local inst = {}

  function inst.close()
    local socket = nil
    raw_socket, socket = socket, raw_socket

    shutdown(socket)
  end

  function inst.isOpen()
    return raw_socket and true or false
  end

  function inst.open()
    local socket = _r.socket(r)
    socket:settimeout(0)

    local status, err = socket:connect(host, port)

    if not status and suppress_write_error(socket, err) then
      return _r.logger(r, err)
    end

    if ssl_params then
      socket = ssl.wrap(socket, ssl_params)
      status = false
      while not status do
        status, err = socket:dohandshake()
        if suppress_read_error(socket, err) then
          return _r.logger(r, err)
        end
      end
    end

    raw_socket, socket = socket, raw_socket

    shutdown(socket)
  end

  function inst.recv()
    if not raw_socket then return nil, 'closed' end
    local buf, err, partial = raw_socket:receive('*a')
    if buf then
      return buf
    end
    if suppress_read_error(raw_socket, err) then
      return nil, _r.logger(r, err)
    end
    return partial or ''
  end

  function inst.send(...)
    if not raw_socket then return nil, 'closed' end
    local data = table.concat{...}
    local idx, err, err_idx = raw_socket:send(data)
    if idx == #data then
      return idx
    end
    if suppress_write_error(raw_socket, err) then
      return nil, _r.logger(r, err)
    end
    return err_idx
  end

  function inst.get_message(buffer)
    local i = nil
    while not i do
      local buf, err = inst.recv()
      if not buf then
        return nil, err
      end
      buffer = buffer .. buf
      i = (string.find(buffer, '\0'))
    end

    local message = string.sub(buffer, 1, i - 1)
    buffer = string.sub(buffer, i + 1)
    return message, buffer
  end

  function inst.decode_message(buffer)
    local message
    message, buffer = inst.get_message(buffer)

    if message == nil then
      return nil, buffer
    end

    local success, response = pcall(_r.decode, r, message)

    if not success then
      return nil, response
    end

    return response, buffer
  end

  return inst
end
