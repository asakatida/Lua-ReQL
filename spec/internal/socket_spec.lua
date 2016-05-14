describe('socket', function()
  local socket

  setup(function()
    socket = require('rethinkdb.socket')
  end)

  teardown(function()
    socket = nil
  end)

  it('available functions', function()
    assert.are_same('function', type(socket))
  end)
end)
