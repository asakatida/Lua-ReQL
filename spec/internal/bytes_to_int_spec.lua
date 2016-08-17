local binstring = require('luassert.formatters.binarystring')

describe('bytes to int', function()
  local bytes_to_int

  setup(function()
    assert:add_formatter(binstring)
    bytes_to_int = require('rethinkdb.internal.bytes_to_int')
  end)

  teardown(function()
    bytes_to_int = nil
    assert:remove_formatter(binstring)
  end)

  it('endian', function()
    assert.same(1, bytes_to_int.little'\1\0\0')
    assert.same(65536, bytes_to_int.big'\1\0\0')
  end)

  it('bom', function()
    assert.same(0xFFEF, bytes_to_int.little'\239\255')
    assert.same(0xEFFF, bytes_to_int.big'\239\255')
  end)

  it('large number', function()
    assert.same(2 ^ 31 - 1, bytes_to_int.little'\255\255\255\127')
    assert.same(2 ^ 31 - 1, bytes_to_int.big'\127\255\255\255')
  end)

  it('long bytes', function()
    assert.same(0, bytes_to_int.little'\0\0\0\0\0\0\0\0\0')
    assert.same(0, bytes_to_int.big'\0\0\0\0\0\0\0\0\0')
  end)

  it('roundtrip endian', function()
    local int_to_bytes = require('rethinkdb.internal.int_to_bytes')
    local orig = '\1\0\0'
    assert.same(orig, int_to_bytes.little(bytes_to_int.little(orig), string.len(orig)))
    assert.same(orig, int_to_bytes.big(bytes_to_int.big(orig), string.len(orig)))
    assert.are_not_equal(orig, int_to_bytes.little(bytes_to_int.little(orig), 7))
    assert.are_not_equal(orig, int_to_bytes.big(bytes_to_int.big(orig), 7))
    assert.are_not_equal(orig, int_to_bytes.little(bytes_to_int.little(orig), 1))
    assert.are_not_equal(orig, int_to_bytes.big(bytes_to_int.big(orig), 1))
  end)

  it('roundtrip bom', function()
    local int_to_bytes = require('rethinkdb.internal.int_to_bytes')
    local orig = '\239\255'
    assert.same(orig, int_to_bytes.little(bytes_to_int.little(orig), string.len(orig)))
    assert.same(orig, int_to_bytes.big(bytes_to_int.big(orig), string.len(orig)))
    assert.are_not_equal(orig, int_to_bytes.little(bytes_to_int.little(orig), 5))
    assert.are_not_equal(orig, int_to_bytes.big(bytes_to_int.big(orig), 5))
    assert.are_not_equal(orig, int_to_bytes.little(bytes_to_int.little(orig), 3))
    assert.are_not_equal(orig, int_to_bytes.big(bytes_to_int.big(orig), 3))
  end)

  it('roundtrip large number', function()
    local int_to_bytes = require('rethinkdb.internal.int_to_bytes')
    local orig = '\255\255\255\127'
    assert.same(orig, int_to_bytes.little(bytes_to_int.little(orig), string.len(orig)))
    assert.same(orig, int_to_bytes.big(bytes_to_int.big(orig), string.len(orig)))
    assert.are_not_equal(orig, int_to_bytes.little(bytes_to_int.little(orig), 8))
    assert.are_not_equal(orig, int_to_bytes.big(bytes_to_int.big(orig), 8))
    assert.are_not_equal(orig, int_to_bytes.little(bytes_to_int.little(orig), 2))
    assert.are_not_equal(orig, int_to_bytes.big(bytes_to_int.big(orig), 2))
  end)

  it('roundtrip long bytes', function()
    local int_to_bytes = require('rethinkdb.internal.int_to_bytes')
    local orig = '\0\0\0\0\0\0\0\0\0'
    assert.same(orig, int_to_bytes.little(bytes_to_int.little(orig), string.len(orig)))
    assert.same(orig, int_to_bytes.big(bytes_to_int.big(orig), string.len(orig)))
  end)
end)
