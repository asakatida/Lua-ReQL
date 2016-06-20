local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('utilities', function()
  local utilities

  setup(function()
    assert:add_formatter(reql_error_formatter)
    utilities = require('rethinkdb.utilities')
  end)

  teardown(function()
    utilities = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('available functions', function()
    assert.are_same('function', type(utilities.decode))
  end)
end)
