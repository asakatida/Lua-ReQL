describe('errors', function()
  local errors

  setup(function()
    errors = require('rethinkdb.errors')
  end)

  teardown(function()
    errors = nil
  end)

  it('available functions', function()
    assert.are_same('function', type(errors.ReQLDriverError))
  end)
end)
