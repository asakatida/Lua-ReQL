--- Interface
-- @module rethinkdb.connection
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local m = {}

function m.init(r)
  function r.connect(host, callback)
    if type(host) == 'function' then
      callback = host
      host = {}
    elseif type(host) == 'string' then
      host = {host = host}
    end
    return r.connector(host).connect(callback)
  end
end

return m
