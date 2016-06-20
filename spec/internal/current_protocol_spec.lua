local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('current protocol', function()
  local r, socket, current_protocol

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')
    socket = require('rethinkdb.socket')
    current_protocol = require('rethinkdb.current_protocol')
  end)

  teardown(function()
    current_protocol = nil
    socket = nil
    r = nil
    assert:remove_formatter(reql_error_formatter)
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
