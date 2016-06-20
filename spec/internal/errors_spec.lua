local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('errors', function()
  local errors

  setup(function()
    assert:add_formatter(reql_error_formatter)
    errors = require('rethinkdb.errors')
  end)

  teardown(function()
    errors = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('available functions', function()
    assert.are_same('function', type(errors.ReQLDriverError))
  end)
end)
