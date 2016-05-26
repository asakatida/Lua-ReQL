--- Helper to determine type of public interface.
-- @module rethinkdb.type
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016

local function type_(obj)
  if type(obj) ~= 'table' or getmetatable(obj) == nil then return nil end

  if type(obj.build) == 'function' and type(obj.compose) == 'function' then
    return 'reql'
  end

  if type(obj._start) == 'function' and type(obj.use) == 'function' then
    if obj.connect == nil then
      return 'pool'
    end

    if type(obj.noreply_wait) == 'function' then
      return 'connection'
    end

    return 'connector'
  end

  if type(obj.each) == 'function' and type(obj.to_array) == 'function' then
    return 'cursor'
  end

  if type(obj.msg) == 'string' and type(obj.message) == 'function' then
    return 'error'
  end

  return nil
end

return type_
