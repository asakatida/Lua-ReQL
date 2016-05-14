describe('connection', function()
  local connection

  setup(function()
    connection = require('rethinkdb.connection')
  end)

  teardown(function()
    connection = nil
  end)

  it('available functions', function()
    assert.are_same('function', type(connection))
  end)
end)
