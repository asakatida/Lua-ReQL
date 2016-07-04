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
    socket = require('rethinkdb.internal.socket')
  end)

  teardown(function()
    socket = nil
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('closes repeatedly', function()
    local client = assert.is_not_nil(socket(r, 'localhost', 28015, nil, 1))
    client.close()
    client.close()
  end)

  it('connects', function()
    local client = assert.is_not_nil(socket(r, 'localhost', 28015, nil, 1))

    finally(function() client.close() end)

    assert.are_equal(12, client.send('\0\0', '\0\0\0\0\0\0\0\0\0\0'))

    local message, err = client.recv'*a'

    assert.is_nil(err)

    assert.are_equal(
      'ERROR: Received an unsupported protocol version. This port is for ' ..
      'RethinkDB queries. Does your client driver version not match the ' ..
      'server?\n\0',
      message)
  end)
end)
