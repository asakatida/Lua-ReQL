--- Helpers to allow overriding driver internals.
-- @module rethinkdb.internal.utilities
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local mime = require('mime')

local json, socket

if ngx == nil then  --luacheck: globals ngx
  json = require('json')
  socket = require('socket')
else
  json = require('cjson')
  socket = ngx.socket  --luacheck: globals ngx
end

local m = {}

function m.init(r, driver_options)
  if not driver_options.mime then
    driver_options.mime = mime
  end
  if not driver_options.b64 then
    driver_options.b64 = driver_options.mime.b64
  end
  if not driver_options.unb64 then
    driver_options.unb64 = driver_options.mime.unb64
  end

  if not driver_options.json then
    driver_options.json = json
  end
  if not driver_options.decode then
    driver_options.decode = driver_options.json.decode
  end
  if not driver_options.encode then
    driver_options.encode = driver_options.json.encode
  end

  if not driver_options.socket then
    driver_options.socket = socket
  end
  if not driver_options.tcp then
    driver_options.tcp = driver_options.socket.tcp
  end

  r.r = r

  r.b64 = driver_options.b64
  r.unb64 = driver_options.unb64

  r.decode = driver_options.decode
  r.encode = driver_options.encode

  r.tcp = driver_options.tcp

  r.socket = driver_options.socket
end

return m
