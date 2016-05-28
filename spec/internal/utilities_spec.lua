describe('utilities', function()
  local utilities

  setup(function()
    utilities = require('rethinkdb.utilities')
  end)

  teardown(function()
    utilities = nil
  end)

  it('available functions', function()
    assert.are_same('function', type(utilities.decode))
  end)
end)
