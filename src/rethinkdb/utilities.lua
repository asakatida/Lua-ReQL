local _r = {}

function _r.logger(r, err)
  if r.logger then
    r.logger(err)
  elseif type(err) == 'string' then
    error(err)
  elseif type(err) == 'table' and err.msg then
    error(err.msg)
  else
    error('Unknown error type from driver')
  end
end

function _r.unb64(r, data)
  if r.unb64 then
    return r.unb64(data)
  elseif not _r.lib_mime then
    _r.lib_mime = require('mime')
  end
  r.unb64 = _r.lib_mime.unb64
  return r.unb64(data)
end

function _r.b64(r, data)
  if r.b64 then
    return r.b64(data)
  elseif not _r.lib_mime then
    _r.lib_mime = require('mime')
  end
  r.b64 = _r.lib_mime.b64
  return r.b64(data)
end

function _r.encode(r, data)
  if r.encode then
    return r.encode(data)
  elseif r.json_parser then
    r.encode = r.json_parser.encode
    return r.encode(data)
  elseif not _r.lib_json then
    if ngx == nil then
      _r.lib_json = require('json')
    else
      _r.lib_json = require('cjson')
    end
  end
  r.json_parser = _r.lib_json
  r.encode = _r.lib_json.encode
  return r.encode(data)
end

function _r.decode(r, buffer)
  if r.decode then
    return r.decode(buffer)
  elseif r.json_parser then
    r.decode = r.json_parser.decode
    return r.decode(buffer)
  elseif not _r.lib_json then
    if ngx == nil then
      _r.lib_json = require('json')
    else
      _r.lib_json = require('cjson')
    end
  end
  r.json_parser = _r.lib_json
  r.decode = _r.lib_json.decode
  return r.decode(buffer)
end

function _r.socket(r)
  if r.socket then
    return r.socket()
  elseif not _r.lib_socket then
    if ngx == nil then
      _r.lib_socket = require('socket')
    else
      _r.lib_socket = ngx.socket
    end
  end
  r.socket = _r.lib_socket.tcp
  return r.socket()
end

function _r.select(r, ...)
  if r.select then
    return r.select(...)
  elseif not _r.lib_socket then
    if ngx == nil then
      _r.lib_socket = require('socket')
    else
      _r.lib_socket = ngx.socket
    end
  end
  r.select = _r.lib_socket.select
  return r.select(...)
end

return _r
