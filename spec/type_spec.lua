local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('type', function()
  local r

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')
  end)

  teardown(function()
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('core types', function()
    assert.is_nil(r.type'string')
    assert.is_nil(r.type(0))
    assert.is_nil(r.type(3))
    assert.is_nil(r.type(nil))
    assert.is_nil(r.type(true))
    assert.is_nil(r.type{})
    assert.is_nil(r.type{r = r})
  end)
end)
