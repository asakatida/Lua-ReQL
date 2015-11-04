local r = require('rethinkdb')

describe('connection', function()
  it('basic', function()
    r.connect(function(err, c)
      if err then error(err.message) end
      assert.are_not.equal(c, nil)
    end)
  end)

  it('return conn', function()
    local conn = r.connect()
    assert.are_not.equal(conn, nil)
    assert.are.equal(conn:open(), true)
    conn:close()
    assert.are.equal(conn:open(), false)
  end)

  it('basic_pool', function()
    r.pool({}, function(err, p)
      if err then error(err.message) end
      assert.are_not.equal(p, nil)
    end)
  end)

  it('fails to insert eventually', function()
    local reql_db = 'connection'
    local reql_table = 'tests'

    local c, err = r.connect()
    if err then error(err.message) end

    r.db_create(reql_db):run(c)
    c:use(reql_db)
    r.table_create(reql_table):run(c)

    assert.has_error(
      function()
        for _id=1,500000 do
          r.table(reql_table):insert({id=_id}):run(c)
        end
      end,
      'ReQLDriverError Connection is closed.'
    )

    c:reconnect(function(err, conn)
      if err then error(err.message) end
      r.table(reql_table):delete():run(conn)
    end)
  end)
end)
