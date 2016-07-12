local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

local ltn12 = require('ltn12')

local log, buffer = ltn12.sink.table()

local function filter(chunk)
  if chunk then
    local success, err = ltn12.pump.all(ltn12.source.string(chunk), log)
    if not success then
      return nil, err
    end
  end
  return chunk
end

describe('current handshake', function()
  local r, socket, current_handshake

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')
    socket = require('rethinkdb.internal.socket')
    current_handshake = require('rethinkdb.internal.current_handshake')
  end)

  teardown(function()
    current_handshake = nil
    socket = nil
    r = nil
    assert:remove_formatter(reql_error_formatter)
    assert.is_nil(string.gsub(table.concat(buffer), '[^%g]', function(s)
      return string.format('\\u%d', string.byte(s))
    end))
  end)

  it('no password', function()
    local client, err = socket(r, 'localhost', 28015, nil, 20)
    assert.is_nil(err)
    assert.is_not_nil(client)
    finally(client.close)

    client.sink = ltn12.sink.chain(filter, client.sink)
    local source = client.source
    function client.source(length)
      return ltn12.source.chain(source(length), filter)
    end

    local success

    success, err = current_handshake(client, '', 'admin')
    assert.is_nil(err)
    assert.is_true(success)
  end)
end)
