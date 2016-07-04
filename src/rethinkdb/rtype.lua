--- Interface
-- @module rethinkdb.reql
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local m = {}

function m.init(r)
  --- Helper to determine type of public interface.
  function r.type(obj)
    if type(obj) ~= 'table' then return nil end
    if not getmetatable(obj) then return nil end
    if type(obj.r) ~= 'table' then return nil end

    if type(obj.run) == 'function' then
      return 'reql'
    end

    if type(obj._start) == 'function' and type(obj.use) == 'function' then
      if type(obj.noreply_wait) == 'function' then
        return 'connection'
      end

      return 'connector'
    end

    if type(obj.each) == 'function' and type(obj.to_array) == 'function' then
      return 'cursor'
    end

    if obj.ReQLError then
      return 'error'
    end

    return nil
  end
end

return m
