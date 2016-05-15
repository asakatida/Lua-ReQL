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

  local inst = {
    close = function()
      local socket = nil
      raw_socket, socket = socket, raw_socket

      shutdown(socket)
    end,
    isOpen = function()
      return raw_socket and true or false
    end,
    open = function()
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
    end,
    recv = function()
      if not raw_socket then return nil, 'closed' end
      local buf, err, partial = raw_socket:receive('*a')
      if buf then
        return buf
      end
      if suppress_read_error(raw_socket, err) then
        return nil, _r.logger(r, err)
      end
      return partial or ''
    end,
    send = function(...)
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
  }

  return inst
end
