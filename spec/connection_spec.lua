local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('connection', function()
  local r

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')
  end)

  teardown(function()
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('basic', function()
    r.connect(function(err, c)
      assert.is_nil(err)
      assert.is_not_nil(c)
    end)
  end)

  it('return conn', function()
    local conn, err = r.connect{proto_version = r.proto_V0_4}
    assert.is_nil(err)
    assert.is_not_nil(conn)
    assert.is_true(conn.is_open())
    err = conn.close{noreply_wait = false}
    assert.is_nil(err)
    assert.is_false(conn.is_open())
  end)

  it('noreply wait', function()
    local conn, err = r.connect{proto_version = r.proto_V0_4}
    assert.is_nil(err)
    assert.is_not_nil(conn)
    assert.is_true(conn.is_open())
    err = conn.close()
    assert.is_nil(err)
    assert.is_false(conn.is_open())
  end)

  it('fails to insert eventually', function()
    local reql_db = 'connection'
    local reql_table = 'tests'

    local c, _err = r.connect{proto_version = r.proto_V0_4}
    assert.is_nil(_err)

    r.db_create(reql_db).run(c)
    c.use(reql_db)
    r.table_create(reql_table).run(c)

    -- assert.has_error(
    --   function()
    --     for _id=1,500000 do
    --       local cur, err = r.table(reql_table).insert{id=_id}.run(c)
    --       assert.is_nil(err)
    --       assert.is_nil(cur)
    --     end
    --   end,
    --   'ReQLDriverError Connection is closed.'
    -- )

    c.reconnect(function(err, conn)
      if err then error(err.message()) end
      r.table(reql_table).delete().run(conn)
    end)
  end)
end)
