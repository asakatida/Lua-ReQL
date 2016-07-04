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
    -- current_handshake = nil
    -- socket = nil
    -- r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('no password', function()
    local client = assert.is_not_nil(socket(r, 'localhost', 28015, nil, 1))

    finally(function() client.close() end)

    local one, two = current_handshake(client, '', 'admin')
    assert.is_nil(one)
    assert.is_nil(two)
  end)
end)
