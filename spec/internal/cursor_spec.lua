describe('cursor', function()
  local cursor

  setup(function()
    cursor = require('rethinkdb.cursor')
  end)

  teardown(function()
    cursor = nil
  end)

  it('available functions', function()
    assert.are_same('function', type(cursor))
  end)
end)
