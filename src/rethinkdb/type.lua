--- Helper to determine type of public interface.
-- @module rethinkdb.type

return function(obj)
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
    local success, message = pcall(obj.message)
    if success and type(message) == 'string' then
      return 'error'
    end
  end

  return nil
end
