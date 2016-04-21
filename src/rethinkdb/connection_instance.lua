local bytes_to_int = require'rethinkdb.bytes_to_int'
local Cursor = require'rethinkdb.cursor'
local errors = require'rethinkdb.errors'
local int_to_bytes = require'rethinkdb.int_to_bytes'
local proto = require'rethinkdb.protodef'

local m = {}

function m.init(r, _r)
end
return m
