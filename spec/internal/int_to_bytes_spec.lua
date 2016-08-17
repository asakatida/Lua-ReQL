local binstring = require('luassert.formatters.binarystring')

describe('int to bytes', function()
  local int_to_bytes

  setup(function()
    assert:add_formatter(binstring)
    int_to_bytes = require('rethinkdb.internal.int_to_bytes')
  end)

  teardown(function()
    int_to_bytes = nil
    assert:remove_formatter(binstring)
  end)

  it('endian', function()
    assert.same('\1\0\0', int_to_bytes.little(1, 3))
    assert.same('\0\0\1', int_to_bytes.big(1, 3))
  end)

  it('bom', function()
    assert.same('\239\255', int_to_bytes.little(0xFFEF, 2))
    assert.same('\255\239', int_to_bytes.big(0xFFEF, 2))
  end)

  it('large number', function()
    assert.same('\255\255\255\127', int_to_bytes.little(2 ^ 31 - 1, 4))
    assert.same('\127\255\255\255', int_to_bytes.big(2 ^ 31 - 1, 4))
  end)

  it('long bytes', function()
    assert.same('\0\0\0\0\0\0\0\0', int_to_bytes.little(0, 8))
    assert.same('\0\0\0\0\0\0\0\0', int_to_bytes.big(0, 8))
  end)

  it('insuficient length', function()
    assert.same('\239', int_to_bytes.little(0xFFEF, 1))
    assert.same('\239', int_to_bytes.big(0xFFEF, 1))
  end)

  it('roundtrip endian', function()
    local bytes_to_int = require('rethinkdb.internal.bytes_to_int')
    local orig = 1
    local bytes = int_to_bytes.little(orig, 3)
    assert.same(orig, bytes_to_int.little(bytes))
    bytes = int_to_bytes.big(orig, 3)
    assert.same(orig, bytes_to_int.big(bytes))
  end)

  it('roundtrip empty', function()
    local bytes_to_int = require('rethinkdb.internal.bytes_to_int')
    local orig = 0
    local bytes = int_to_bytes.little(orig, 1)
    assert.same(orig, bytes_to_int.little(bytes))
    bytes = int_to_bytes.big(orig, 1)
    assert.same(orig, bytes_to_int.big(bytes))
    bytes = int_to_bytes.little(orig, 3)
    assert.same(orig, bytes_to_int.little(bytes))
    bytes = int_to_bytes.big(orig, 3)
    assert.same(orig, bytes_to_int.big(bytes))
  end)

  it('roundtrip bom', function()
    local bytes_to_int = require('rethinkdb.internal.bytes_to_int')
    local orig = 0xFFEF
    local bytes = int_to_bytes.little(orig, 2)
    assert.same(orig, bytes_to_int.little(bytes))
    bytes = int_to_bytes.big(orig, 2)
    assert.same(orig, bytes_to_int.big(bytes))
  end)

  it('roundtrip large number', function()
    local bytes_to_int = require('rethinkdb.internal.bytes_to_int')
    local orig = 2 ^ 31 - 1
    local bytes = int_to_bytes.little(orig, 4)
    assert.same(orig, bytes_to_int.little(bytes))
    bytes = int_to_bytes.big(orig, 4)
    assert.same(orig, bytes_to_int.big(bytes))
  end)

  it('roundtrip long bytes', function()
    local bytes_to_int = require('rethinkdb.internal.bytes_to_int')
    local orig = 0
    local bytes = int_to_bytes.little(orig, 8)
    assert.same(orig, bytes_to_int.little(bytes))
    bytes = int_to_bytes.big(orig, 8)
    assert.same(orig, bytes_to_int.big(bytes))
  end)

  it('roundtrip insuficient length', function()
    local bytes_to_int = require('rethinkdb.internal.bytes_to_int')
    local orig = 2 ^ 31 - 1
    local bytes = int_to_bytes.little(orig, 3)
    assert.are_not_equal(orig, bytes_to_int.little(bytes))
    bytes = int_to_bytes.big(orig, 3)
    assert.are_not_equal(orig, bytes_to_int.big(bytes))
  end)
end)
