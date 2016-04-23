local ast = require'rethinkdb.ast'
local is_instance = require'rethinkdb.is_instance'
local unpack = require 'rethinkdb.unpack'

local m = {}

function m.init(_r)
  local ast_methods = ast.init(_r)

  local function expr(r, val, nesting_depth)
    if nesting_depth == nil then
      nesting_depth = 20
    end
    if type(nesting_depth) ~= 'number' then
      return _r.logger('Second argument to `r(val, nesting_depth)` must be a number.')
    end
    if nesting_depth <= 0 then
      return _r.logger('Nesting depth limit exceeded')
    end
    if is_instance(val, 'ReQLOp') and type(val.build) == 'function' then
      return val
    end
    if type(val) == 'function' then
      return ast_methods.func({}, val)
    end
    if type(val) == 'table' then
      local array = true
      for k, v in pairs(val) do
        if type(k) ~= 'number' then array = false end
        val[k] = r(v, nesting_depth - 1)
      end
      if array then
        return ast_methods.make_array({}, unpack(val))
      end
      return ast_methods.make_obj(val)
    end
    if type(val) == 'userdata' then
      val = pcall(tostring, val)
      _r.logger('Found userdata inserting "' .. val .. '" into query')
      return ast_methods.datum(val)
    end
    if type(val) == 'thread' then
      val = pcall(tostring, val)
      _r.logger('Cannot insert thread object into query ' .. val)
      return nil
    end
    return ast_methods.datum(val)
  end

  return expr
end

return m
