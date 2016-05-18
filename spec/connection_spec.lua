describe('connection', function()
  local r

  setup(function()
    r = require('rethinkdb')
  end)

  teardown(function()
    r = nil
  end)

  it('basic', function()
    r.connect(function(err, c)
      if err then error(err.message()) end
      assert.is_not_nil(c)
    end)
  end)

  it('return conn', function()
    local conn = r.connect()
    assert.is_not_nil(conn)
    assert.is_true(conn.is_open())
    conn.close()
    assert.is_false(conn.is_open())
  end)

  it('basic pool', function()
    r.pool({}, function(err, p)
      if err then error(err.message()) end
      assert.is_not_nil(p)
    end)
  end)

  it('fails to insert eventually', function()
    local reql_db = 'connection'
    local reql_table = 'tests'

    local c, _err = r.connect()
    if _err then error(_err.message()) end

    r.db_create(reql_db).run(c)
    c.use(reql_db)
    r.table_create(reql_table).run(c)

    assert.has_error(
      function()
        for _id=1,500000 do
          r.table(reql_table).insert{id=_id}.run(c)
        end
      end,
      'ReQLDriverError Connection is closed.'
    )

    c.reconnect(function(err, conn)
      if err then error(err.message()) end
      r.table(reql_table).delete().run(conn)
    end)
  end)
end)
