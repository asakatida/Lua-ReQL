local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('bits', function()
  local bits

  setup(function()
    assert:add_formatter(reql_error_formatter)
    bits = require('rethinkdb.bits')
  end)

  teardown(function()
    bits = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('tobit', function()
    assert.same(7, bits.tobit(7))
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
