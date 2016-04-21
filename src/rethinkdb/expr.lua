local m = {}

function m.init(r, _r)
  function expr(cls, val, nesting_depth)
    if nesting_depth == nil then
      nesting_depth = 20
    end
    if type(nesting_depth) ~= 'number' then
      return _r.logger('Second argument to `r(val, nesting_depth)` must be a number.')
    end
    if nesting_depth <= 0 then
      return _r.logger('Nesting depth limit exceeded')
    end
    if r.is_instance(val, 'ReQLOp') and type(val.build) == 'function' then
      return val
    end
    if type(val) == 'function' then
      return ast.FUNC({}, val)
    end
    if type(val) == 'table' then
      local array = true
      for k, v in pairs(val) do
        if type(k) ~= 'number' then array = false end
        val[k] = r(v, nesting_depth - 1)
      end
      if array then
        return ast.MAKE_ARRAY({}, unpack(val))
      end
      return ast.MAKE_OBJ(val)
    end
    if type(val) == 'userdata' then
      val = pcall(tostring, val)
      _r.logger('Found userdata inserting "' .. val .. '" into query')
      return ast.DATUMTERM(val)
    end
    if type(val) == 'thread' then
      val = pcall(tostring, val)
      _r.logger('Cannot insert thread object into query ' .. val)
      return nil
    end
    return ast.DATUMTERM(val)
  end

  setmetatable(r, {__call = expr})

  return expr
end

return m
