local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('ast', function()
  local ast

  setup(function()
    assert:add_formatter(reql_error_formatter)
    ast = require('rethinkdb.ast')
  end)

  teardown(function()
    ast = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('available functions', function()
    assert.is_not_nil(getmetatable(ast))
    assert.are_same('table', type(ast))
    assert.is_not_nil(ast())
  end)
end)
