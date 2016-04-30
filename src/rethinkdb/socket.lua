local m = {}

function m.init(_r)
  return function(host, port, ssl_params, timeout)
    local raw_socket

    local inst = {
      __name = 'Socket',
      close = function()
        local socket = nil
        raw_socket, socket = socket, raw_socket

        if socket then
          if ngx == nil and ssl_params == nil then
            socket:shutdown()
          end
          socket:close()
        end
      end,
      isOpen = function()
        return raw_socket and true or false
      end,
      open = function()
        local socket = _r.socket()
        socket:settimeout(timeout)

        local status, err = socket:connect(host, port)

        if ssl_params then
          socket = _r.lib_ssl.wrap(socket, ssl_params)
          status = false
          while not status do
            status, err = socket:dohandshake()
            if err == "timeout" or err == "wantread" then
              _r.select({socket}, nil)
            elseif err == "wantwrite" then
              _r.select(nil, {socket})
            else
              _r.logger(err)
            end
          end

          raw_socket = socket
        end
      end,
      recv = function()
        if not raw_socket then return nil, 'closed' end
        local buf, err, partial = raw_socket:receive()
        return buf or partial
      end,
      send = function(...)
        if not raw_socket then return nil, 'closed' end
        return raw_socket:send(table.concat({...}))
      end
    }

    return inst
  end
end

return m
