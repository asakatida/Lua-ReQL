describe('connection instance', function()
  local connection_instance

  setup(function()
    connection_instance = require('rethinkdb.connection_instance')
  end)

  teardown(function()
    connection_instance = nil
  end)

  it('available functions', function()
    assert.are_same('function', type(connection_instance))
  end)
end)
