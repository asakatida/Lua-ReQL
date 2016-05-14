describe('type', function()
  local type

  setup(function()
    type = require('rethinkdb.type')
  end)

  teardown(function()
    type = nil
  end)

  it('core types', function()
    assert.is_nil(type('string'))
    assert.is_nil(type(0))
    assert.is_nil(type(3))
    assert.is_nil(type(nil))
    assert.is_nil(type(true))
    assert.is_nil(type({}))
  end)
end)
