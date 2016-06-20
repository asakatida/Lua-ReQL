local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('change feeds', function()
  local r, reql_db, reql_table, c

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')

    reql_db = 'changefeeds'
    reql_table = 'watched'

    local err

    c, err = r.connect{proto_version = r.proto_V0_4}
    assert.is_nil(err)

    r.reql.db_create(reql_db).run(c)
    c.use(reql_db)
    r.reql.table_create(reql_table).run(c)
  end)

  before_each(function()
    r.reql.table(reql_table).insert{
      {id = 1}, {id = 2}, {id = 3},
      {id = 4}, {id = 5}, {id = 6}
    }.run(c)
  end)

  after_each(function()
    r.reql.table(reql_table).delete().run(c)
  end)

  teardown(function()
    r.reql.table(reql_table).delete().run(c)
    c.close()
    c = nil
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('all', function()
    local res = r.table(reql_table).changes().limit(4).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        r.table(reql_table).insert(
          {{id = 7}, {id = 8}, {id = 9}, {id = 10}}
        ).run(c, function(err)
          if err then error(err.message()) end
        end)
        local res = {}
        cur.each(function(row)
          table.insert(res, row.new_val.id)
        end, function(err)
          assert.is_nil(err)
        end)
        return res
      end
    )
    table.sort(res)
    assert.same(res, {7, 8, 9, 10})
  end)

  it('even', function()
    local res = r.table(reql_table).changes().filter(
      function(row)
        return (row('new_val')('id') % 2).eq(0)
      end
    ).limit(2).run(
      c, function(_err, cur)
        if _err then error(_err.message()) end
        r.table(reql_table).insert(
          {{id = 7}, {id = 8}, {id = 9}, {id = 10}}
        ).run(c, function(err)
          if err then error(err.message()) end
        end)
        local res = {}
        cur.each(function(row)
          table.insert(res, row.new_val.id)
        end, function(err)
          assert.is_nil(err)
        end)
        return res
      end
    )
    table.sort(res)
    assert.same(res, {8, 10})
  end)
end)
