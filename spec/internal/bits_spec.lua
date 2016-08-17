describe('bits', function()
  local bits

  setup(function()
    bits = require('rethinkdb.internal.bits51')
  end)

  teardown(function()
    bits = nil
  end)

  it('or 1', function()
    assert.same(5, bits.bor(5, 4))
  end)

  it('or 2', function()
    assert.same(13, bits.bor(13, 0))
  end)

  it('or 3', function()
    assert.same(116, bits.bor(96, 20))
  end)

  it('xor 1', function()
    assert.same(1, bits.bxor(5, 4))
  end)

  it('xor 2', function()
    assert.same(13, bits.bxor(13, 0))
  end)

  it('xor 3', function()
    assert.same(116, bits.bxor(96, 20))
  end)
end)
