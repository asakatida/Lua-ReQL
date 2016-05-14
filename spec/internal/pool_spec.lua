describe('pool', function()
  local pool

  setup(function()
    pool = require('rethinkdb.pool')
  end)

  teardown(function()
    pool = nil
  end)

  it('available functions', function()
    assert.are_same('function', type(pool))
  end)
end)
