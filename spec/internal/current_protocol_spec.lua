describe('current protocol', function()
  local r, socket, current_protocol

  setup(function()
    r = require('rethinkdb')
    socket = require('rethinkdb.socket')
    current_protocol = require('rethinkdb.current_protocol')
  end)

  teardown(function()
    socket = nil
    current_protocol = nil
    r = nil
  end)

  it('no password', function()
    local client = assert.is_not_nil(socket(r, 'localhost', 28015, nil, 1))

    client.open()

    assert.is_true(client.is_open())

    finally(function() client.close() end)

    local one, two, three = current_protocol(client, '', 'admin')
    assert.is_nil(one)
    assert.is_nil(two.message())
    assert.is_nil(three)
  end)
end)
