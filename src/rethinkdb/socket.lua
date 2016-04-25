local m = {}

function m.init(_r)
  return function(host, port, ssl_params, timeout)
    local raw_socket

    local inst = {
      __name = 'Socket',
      close = function()
        if raw_socket then
          if ngx == nil and ssl_params == nil then
            raw_socket:shutdown()
          end
          raw_socket:close()
          raw_socket = nil
        end
      end,
      isOpen = function()
        return raw_socket and true or false
      end,
      open = function()
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
      end,
      recv = function()
        if not raw_socket then return nil, 'closed' end
        local buf, err, partial = raw_socket:receive()
        return buf or partial
      end,
      send = function(buffer, ...)
        if not raw_socket then return nil, 'closed' end
        return raw_socket:send(buffer)
      end
    }

    return inst
  end
end

return m
