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
    local client = assert.is_not_nil(socket({}, 'localhost', 28015, nil, 1))

    finally(function() client.close() end)

    assert.is_false(client.is_open())

    client.close()

    assert.is_false(client.is_open())

    client.open()

    assert.is_true(client.is_open())

    client.close()

    assert.is_false(client.is_open())

    client.close()

    client.open()

    assert.is_true(client.is_open())

    client.open()

    assert.is_true(client.is_open())
  end)

  it('connects', function()
    local client = assert.is_not_nil(socket({}, 'localhost', 28015, nil, 1))

    client.open()

    assert.is_true(client.is_open())

    finally(function() client.close() end)

    local idx = assert.is_not_nil(client.send('\0\0', '\0\0\0\0\0\0\0\0\0\0'))

    assert.are_equal(12, idx)

    local message = assert.is_not_nil(client.recv())

    assert.are_equal(
      'ERROR: Received an unsupported protocol version. This port is for ' ..
      'RethinkDB queries. Does your client driver version not match the ' ..
      'server?\n\0',
      message)

    client.close()
  end)
end)
