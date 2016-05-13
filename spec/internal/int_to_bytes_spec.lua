describe('int to bytes', function()
  local int_to_bytes

  setup(function()
    int_to_bytes = require('rethinkdb.int_to_bytes')
  end)

  teardown(function()
    int_to_bytes = nil
  end)

  local function test(name, int, len, bytes)
    it(name, function()
      assert.same(bytes, int_to_bytes(int, len))
    end)
  end

  local function roundtrip(name, orig, len)
    it('roundtrip ' .. name, function()
      local bytes_to_int = require('rethinkdb.bytes_to_int')
      local bytes = int_to_bytes(orig, len)
      assert.same(orig, bytes_to_int(bytes))
    end)
  end

  test('endian', 1, 3, '\1\0\0')
  test('empty', 0, 0, '')
  test('bom', 0xFFEF, 2, '\239\255')
  test('large number', 2 ^ 31 - 1, 4, '\255\255\255\127')
  test('long bytes', 0, 8, '\0\0\0\0\0\0\0\0\0')

  roundtrip('endian', 1, 3)
  roundtrip('empty', 0, 0)
  roundtrip('bom', 0xFFEF, 2)
  roundtrip('large number', 2 ^ 31 - 1, 4)
  roundtrip('long bytes', 0, 8)
end)
