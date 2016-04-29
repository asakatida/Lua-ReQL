package = 'Lua-ReQL'
version = '1.0-0'
source = {
  url = 'git://github.com/grandquista/Lua-ReQL',
  tag = 'v1.0.0',
}
description = {
  summary = 'A Lua driver for RethinkDB.',
  homepage = 'https://github.com/grandquista/Lua-ReQL/wiki',
  license = 'Apache',
}
dependencies = {
  'lua >= 5.1',
  'luacrypto',
  'luasocket ~> 3',
  'luasec',
  'luajson ~> 1',
}
build = {
  type = 'builtin',
  modules = {
    ['rethinkdb.ast'] = 'src/rethinkdb/ast.lua',
    ['rethinkdb.bytes_to_int'] = 'src/rethinkdb/bytes_to_int.lua',
    ['rethinkdb.connection_instance'] = 'src/rethinkdb/connection_instance.lua',
    ['rethinkdb.connection'] = 'src/rethinkdb/connection.lua',
    ['rethinkdb.convert_pseudotype'] = 'src/rethinkdb/convert_pseudotype.lua',
    ['rethinkdb.cursor'] = 'src/rethinkdb/cursor.lua',
    ['rethinkdb.errors'] = 'src/rethinkdb/errors.lua',
    ['rethinkdb.int_to_bytes'] = 'src/rethinkdb/int_to_bytes.lua',
    ['rethinkdb.is_instance'] = 'src/rethinkdb/is_instance.lua',
    ['rethinkdb.pool'] = 'src/rethinkdb/pool.lua',
    ['rethinkdb.protodef'] = 'src/rethinkdb/protodef.lua',
    rethinkdb = 'src/rethinkdb.lua'
  }
}
