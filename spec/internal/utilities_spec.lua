describe('utilities', function()
  local utilities

  setup(function()
    utilities = require('rethinkdb.internal.utilities')
  end)

  teardown(function()
    utilities = nil
  end)

  it('available functions', function()
    local r = {}

    utilities.init(r, {})

    assert.are_same(r.r, r)

    assert.is_not_nil(r.b64)
    assert.is_not_nil(r.unb64)

    assert.is_not_nil(r.decode)
    assert.is_not_nil(r.encode)

    assert.is_not_nil(r.tcp)

    assert.is_not_nil(r.socket)
  end)
end)
