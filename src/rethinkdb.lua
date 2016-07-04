--- Main interface combining public modules in an export table.
-- @module rethinkdb
-- @author Adam Grandquist
-- @license Apache
-- @copyright Adam Grandquist 2016
-- @alias r

local connection = require'rethinkdb.connection'
local current_handshake = require'rethinkdb.internal.current_handshake'
local depreciate = require'rethinkdb.depreciate'
local utilities = require'rethinkdb.internal.utilities'
local reql = require'rethinkdb.reql'
local rtype = require'rethinkdb.rtype'

local v = require('rethinkdb.internal.semver')

local function new(driver_options)
  driver_options = driver_options or {}

  -- r is the main export table for the module
  local r = {}

  r.b64 = utilities.b64(driver_options)
  r.decode = utilities.decode(driver_options)
  r.encode = utilities.encode(driver_options)
  r.new = new
  r.proto_V1_0 = current_handshake
  r.r = r
  r.select = utilities._select(driver_options)
  r.socket = utilities.socket(driver_options)
  r.unb64 = utilities.unb64(driver_options)
  r.version = v'1.0.0'
  r._VERSION = r.version

  connection.init(r)
  depreciate.init(r)
  reql.init(r)
  rtype.init(r)

  return r
end

return new()
