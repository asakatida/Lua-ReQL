describe('convert pseudotype', function()
  local convert_pseudotype

  setup(function()
    convert_pseudotype = require('rethinkdb.internal.convert_pseudotype')
  end)

  teardown(function()
    convert_pseudotype = nil
  end)

  it('available functions', function()
    assert.are_same('function', type(convert_pseudotype))
  end)
end)
