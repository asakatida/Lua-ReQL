local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('connection instance', function()
  local connection_instance

  setup(function()
    assert:add_formatter(reql_error_formatter)
    connection_instance = require('rethinkdb.connection_instance')
  end)

  teardown(function()
    connection_instance = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('available functions', function()
    assert.are_same('function', type(connection_instance))
  end)
end)
