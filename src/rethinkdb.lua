--- Main interface combining public modules in an export table.
-- @module rethinkdb
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016
-- @alias r

local connection = require'rethinkdb.connection'
local connector = require'rethinkdb.connector'
local current_handshake = require'rethinkdb.internal.current_handshake'
local depreciate = require'rethinkdb.depreciate'
local utilities = require'rethinkdb.internal.utilities'
local reql = require'rethinkdb.reql'
local rtype = require'rethinkdb.rtype'

local v = require('rethinkdb.internal.semver')

local function new(driver_options)
  -- r is the main export table for the module
  local r = {}

  r.new = new
  r.proto_V1_0 = current_handshake
  r.version = v'1.0.0'
  r._VERSION = r.version

  connection.init(r)
  connector.init(r)
  depreciate.init(r)
  reql.init(r)
  rtype.init(r)
  utilities.init(r, driver_options or {})

  return r
end

return new()
