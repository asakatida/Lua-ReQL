describe('bytes to int', function()
  local bytes_to_int

  setup(function()
    bytes_to_int = require('rethinkdb.bytes_to_int')
  end)

  teardown(function()
    bytes_to_int = nil
  end)

  it('endian', function()
    assert.same(1, bytes_to_int'\1\0\0')
  end)

  it('empty', function()
    assert.same(0, bytes_to_int'')
  end)

  it('bom', function()
    assert.same(0xFFEF, bytes_to_int'\239\255')
  end)

  it('large number', function()
    assert.same(2 ^ 31 - 1, bytes_to_int'\255\255\255\127')
  end)

  it('long bytes', function()
    assert.same(0, bytes_to_int'\0\0\0\0\0\0\0\0\0')
  end)

  it('roundtrip endian', function()
    local int_to_bytes = require('rethinkdb.int_to_bytes')
    local orig = '\1\0\0'
    assert.same(orig, int_to_bytes(bytes_to_int(orig), #orig))
  end)

  it('roundtrip empty', function()
    local int_to_bytes = require('rethinkdb.int_to_bytes')
    local orig = ''
    assert.same(orig, int_to_bytes(bytes_to_int(orig), #orig))
  end)

  it('roundtrip bom', function()
    local int_to_bytes = require('rethinkdb.int_to_bytes')
    local orig = '\239\255'
    assert.same(orig, int_to_bytes(bytes_to_int(orig), #orig))
  end)

  it('roundtrip large number', function()
    local int_to_bytes = require('rethinkdb.int_to_bytes')
    local orig = '\255\255\255\127'
    assert.same(orig, int_to_bytes(bytes_to_int(orig), #orig))
  end)

  it('roundtrip long bytes', function()
    local int_to_bytes = require('rethinkdb.int_to_bytes')
    local orig = '\0\0\0\0\0\0\0\0\0'
    assert.same(orig, int_to_bytes(bytes_to_int(orig), #orig))
  end)
end)
