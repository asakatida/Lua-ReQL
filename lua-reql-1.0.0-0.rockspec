rockspec_format = '1.1'
package = 'lua-reql'
version = '1.0.0-0'
source = {
  url = 'git://github.com/grandquista/Lua-ReQL',
  branch = 'v1.0.0',
}
description = {
  summary = 'A Lua driver for RethinkDB.',
  detailed = [[
# Lua-ReQL

Rethinkdb driver in Lua

## Installing
- _IF USING LUA 5.1_ `luarocks install luabitop`
- `luarocks install lua-reql`

## Dev Dependencies
- Lua >= 5.1
- Luarocks
  - busted
  - luacheck
  - luacov
  - _IF USING LUA 5.1_ luabitop
- RethinkDB

## Testing
- `luacheck .`
- `busted -c`
- `luacov`

## Installing from source
- `luarocks make`
  ]],
  homepage = 'https://github.com/grandquista/Lua-ReQL/wiki',
  license = 'Apache',
}
dependencies = {
  'lua >= 5.1, < 5.4',
  'luacrypto',
  'luasocket ~> 3',
  'luasec',
  'luajson ~> 1',
}
build = {
  type = 'builtin',
  modules = {
    rethinkdb = 'src/rethinkdb.lua',
    ['rethinkdb.ast'] = 'src/rethinkdb/ast.lua',
    ['rethinkdb.bytes_to_int'] = 'src/rethinkdb/bytes_to_int.lua',
    ['rethinkdb.connection'] = 'src/rethinkdb/connection.lua',
    ['rethinkdb.connection_instance'] = 'src/rethinkdb/connection_instance.lua',
    ['rethinkdb.convert_pseudotype'] = 'src/rethinkdb/convert_pseudotype.lua',
    ['rethinkdb.current_protocol'] = 'src/rethinkdb/current_protocol.lua',
    ['rethinkdb.cursor'] = 'src/rethinkdb/cursor.lua',
    ['rethinkdb.errors'] = 'src/rethinkdb/errors.lua',
    ['rethinkdb.int_to_bytes'] = 'src/rethinkdb/int_to_bytes.lua',
    ['rethinkdb.pool'] = 'src/rethinkdb/pool.lua',
    ['rethinkdb.protodef'] = 'src/rethinkdb/protodef.lua',
    ['rethinkdb.semver'] = 'src/rethinkdb/semver.lua',
    ['rethinkdb.socket'] = 'src/rethinkdb/socket.lua',
    ['rethinkdb.type'] = 'src/rethinkdb/type.lua',
    ['rethinkdb.utilities'] = 'src/rethinkdb/utilities.lua',
  }
}
