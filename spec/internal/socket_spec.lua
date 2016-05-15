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

  it('closes repeatedly', function()
    local client = assert(socket({}, 'localhost', 28015, nil, 1))

    finally(function() client.close() end)

    assert.is_false(client.isOpen())

    client.close()

    assert.is_false(client.isOpen())

    client.open()

    assert.is_true(client.isOpen())

    client.close()

    assert.is_false(client.isOpen())

    client.close()

    client.open()

    assert.is_true(client.isOpen())

    client.open()

    assert.is_true(client.isOpen())
  end)

  it('connects', function()
    local client = assert(socket({}, 'localhost', 28015, nil, 1))

    client.open()

    assert.is_true(client.isOpen())

    finally(function() client.close() end)

    local idx = assert(client.send('\0\0', '\0\0\0\0\0\0\0\0\0\0'))

    assert.are_equal(12, idx)

    local message = assert(client.recv())

    assert.are_equal(
      'ERROR: Received an unsupported protocol version. This port is for ' ..
      'RethinkDB queries. Does your client driver version not match the ' ..
      'server?\n\0',
      message)

    client.close()
  end)
end)
