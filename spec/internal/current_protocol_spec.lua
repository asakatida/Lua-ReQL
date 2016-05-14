describe('current protocol', function()
  local current_protocol

  setup(function()
    current_protocol = require('rethinkdb.current_protocol')
  end)

  teardown(function()
    current_protocol = nil
  end)

  it('available functions', function()
    assert.are_same('function', type(current_protocol))
  end)
end)
