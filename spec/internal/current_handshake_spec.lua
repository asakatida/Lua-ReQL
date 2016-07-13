local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('current handshake', function()
  local r, socket, current_handshake

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')
    socket = require('rethinkdb.internal.socket')
    current_handshake = require('rethinkdb.internal.current_handshake')
  end)

  teardown(function()
    current_handshake = nil
    socket = nil
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('no password', function()
    local client, err = socket(r, 'localhost', 28015, nil, 20)
    assert.is_nil(err)
    assert.is_not_nil(client)
    finally(client.close)

    local success

    success, err = current_handshake(client, '', 'admin')
    assert.is_nil(err)
    assert.is_true(success)
  end)
end)
