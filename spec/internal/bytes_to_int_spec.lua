describe('bytes to int', function()
  local bytes_to_int

  setup(function()
    bytes_to_int = require('rethinkdb.bytes_to_int')
  end)

  teardown(function()
    bytes_to_int = nil
  end)

  local function test(name, bytes, int)
    it(name, function()
      assert.same(int, bytes_to_int(bytes))
    end)
  end

  local function roundtrip(name, orig)
    it('roundtrip ' .. name, function()
      local int_to_bytes = require('rethinkdb.int_to_bytes')
      assert.same(orig, int_to_bytes(bytes_to_int(orig), #orig))
    end)
  end

  test('endian', '\1\0\0', 1)
  test('empty', '', 0)
  test('bom', '\255\255', 0xFFEF)
  test('large number', '\255\255\255\255', 2 ^ 31 - 1)
  test('long bytes', '\0\0\0\0\0\0\0\0\0', 0)

  roundtrip('endian', '\1\0\0')
  roundtrip('empty', '')
  roundtrip('bom', '\255\255')
  roundtrip('large number', '\255\255\255\255')
  roundtrip('long bytes', '\0\0\0\0\0\0\0\0\0')
end)
