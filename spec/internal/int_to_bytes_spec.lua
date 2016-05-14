describe('int to bytes', function()
  local int_to_bytes

  setup(function()
    int_to_bytes = require('rethinkdb.int_to_bytes')
  end)

  teardown(function()
    int_to_bytes = nil
  end)

  it('endian', function()
    assert.same('\1\0\0', int_to_bytes(1, 3))
  end)

  it('empty', function()
    assert.same('', int_to_bytes(0, 0))
  end)

  it('bom', function()
    assert.same('\239\255', int_to_bytes(0xFFEF, 2))
  end)

  it('large number', function()
    assert.same('\255\255\255\127', int_to_bytes(2 ^ 31 - 1, 4))
  end)

  it('long bytes', function()
    assert.same('\0\0\0\0\0\0\0\0\0', int_to_bytes(0, 8))
  end)

  it('roundtrip endian', function()
    local bytes_to_int = require('rethinkdb.bytes_to_int')
    local orig = 1
    local bytes = int_to_bytes(orig, 3)
    assert.same(orig, bytes_to_int(bytes))
  end)

  it('roundtrip empty', function()
    local bytes_to_int = require('rethinkdb.bytes_to_int')
    local orig = 0
    local bytes = int_to_bytes(orig, 0)
    assert.same(orig, bytes_to_int(bytes))
  end)

  it('roundtrip bom', function()
    local bytes_to_int = require('rethinkdb.bytes_to_int')
    local orig = 0xFFEF
    local bytes = int_to_bytes(orig, 2)
    assert.same(orig, bytes_to_int(bytes))
  end)

  it('roundtrip large number', function()
    local bytes_to_int = require('rethinkdb.bytes_to_int')
    local orig = 2 ^ 31 - 1
    local bytes = int_to_bytes(orig, 4)
    assert.same(orig, bytes_to_int(bytes))
  end)

  it('roundtrip long bytes', function()
    local bytes_to_int = require('rethinkdb.bytes_to_int')
    local orig = 0
    local bytes = int_to_bytes(orig, 8)
    assert.same(orig, bytes_to_int(bytes))
  end)
end)
