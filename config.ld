project = 'Lua-ReQL'
title = 'Lua-ReQL documentation'
description = 'A Lua driver for RethinkDB.'

file = {
  'src',
  exclude = {
    'src/rethinkdb/protodef.lua',
    'src/rethinkdb/semver.lua',
    'src/rethinkdb/unpack.lua',
  }
}
format = 'discount'
