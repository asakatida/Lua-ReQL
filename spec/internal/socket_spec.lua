local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('socket', function()
  local r, socket

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')
    socket = require('rethinkdb.socket')
  end)

  teardown(function()
    socket = nil
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('closes repeatedly', function()
    local client = assert.is_not_nil(socket(r, 'localhost', 28015, nil, 1))
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
    local client = assert.is_not_nil(socket(r, 'localhost', 28015, nil, 1))

    client.open()

    assert.is_true(client.is_open())

    finally(function() client.close() end)

    assert.are_equal(12, client.send('\0\0', '\0\0\0\0\0\0\0\0\0\0'))

    local message, err = client.get_success()

    assert.is_nil(message)

    assert.are_equal(
      'ERROR: Received an unsupported protocol version. This port is for ' ..
      'RethinkDB queries. Does your client driver version not match the ' ..
      'server?\n\0',
      err)
  end)
end)
