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
  'luasocket ~> 3',
  'luasec',
  'luajson ~> 1',
}
build = {
  type = 'builtin',
  modules = {
    ['rethinkdb.ast'] = 'src/rethinkdb/ast.lua',
    ['rethinkdb.class'] = 'src/rethinkdb/class.lua',
    ['rethinkdb.convert_pseudotype'] = 'src/rethinkdb/convert_pseudotype.lua',
    ['rethinkdb.cursor'] = 'src/rethinkdb/cursor.lua',
    ['rethinkdb.errors'] = 'src/rethinkdb/errors.lua',
    ['rethinkdb.is_instance'] = 'src/rethinkdb/is_instance.lua',
    rethinkdb = 'src/rethinkdb.lua'
  }
}
