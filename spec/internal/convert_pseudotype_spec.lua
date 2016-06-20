local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('convert pseudotype', function()
  local convert_pseudotype

  setup(function()
    assert:add_formatter(reql_error_formatter)
    convert_pseudotype = require('rethinkdb.convert_pseudotype')
  end)

  teardown(function()
    convert_pseudotype = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('available functions', function()
    assert.are_same('function', type(convert_pseudotype))
  end)
end)
