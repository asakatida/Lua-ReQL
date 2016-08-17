project = 'Lua-ReQL'
title = 'Lua-ReQL documentation'
description = 'A Lua driver for RethinkDB.'

file = {
  'src',
  exclude = {
    'src/rethinkdb/internal/protodef.lua',
    'src/rethinkdb/internal/semver.lua',
  }
}
format = 'discount'
