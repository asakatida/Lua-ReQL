describe('current protocol', function()
  local socket

  setup(function()
    socket = require('rethinkdb.socket')
  end)

  teardown(function()
    socket = nil
  end)

  local r, current_protocol

  setup(function()
    current_protocol = require('rethinkdb.current_protocol')
    r = {}
  end)

  teardown(function()
    current_protocol = nil
    r = nil
  end)

  it('no password', function()
    local client = assert.is_not_nil(socket(r, 'localhost', 28015, nil, 1))

    client.open()

    assert.is_true(client.is_open())

    finally(function() client.close() end)

    local one, two, three = current_protocol(r, client, '', 'admin')
    assert.is_nil(one)
    assert.is_nil(two.message())
    assert.is_nil(three)
  end)
end)
