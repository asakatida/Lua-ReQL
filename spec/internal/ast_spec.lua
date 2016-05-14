describe('ast', function()
  local ast

  setup(function()
    ast = require('rethinkdb.ast')
  end)

  teardown(function()
    ast = nil
  end)

  it('available functions', function()
    assert.is_not_nil(getmetatable(ast))
    assert.are_same('table', type(ast))
  end)
end)
