local function reql_error_formatter(err)
  if type(err) ~= 'table' then return end
  if err.ReQLError then
    return err.message()
  end
end

describe('change feeds', function()
  local r

  setup(function()
    assert:add_formatter(reql_error_formatter)
    r = require('rethinkdb')

    function r.run(query)
      return query.run(query.r.c, function(err, cur)
        return cur, err
      end)
    end

    r.reql_db = r.reql.db'changefeeds'
    r.reql_table = r.reql.table'watched'

    local err

    r.c, err = r.connect{proto_version = r.proto_V0_4}
    assert.is_nil(err)

    r.run(r.reql.db_create'changefeeds')
    r.c.use'changefeeds'
    r.run(r.reql.table_create'watched')
  end)

  before_each(function()
    r.run(r.reql_table.insert{
      {id = 1}, {id = 2}, {id = 3},
      {id = 4}, {id = 5}, {id = 6}
    })
  end)

  after_each(function()
    r.run(r.reql_table.delete())
  end)

  teardown(function()
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('all', function()
    local cur = assert.is_table(r.run(r.reql_table.changes().limit(4)))
    assert.is_table(r.run(r.reql_table.insert(
      {{id = 7}, {id = 8}, {id = 9}, {id = 10}}
    ))).to_array()
    local res = {}
    cur.each(function(row)
      table.insert(res, row.new_val.id)
    end, function(err)
      assert.is_nil(err)
    end)
    table.sort(res)
    assert.same(res, {7, 8, 9, 10})
  end)

  it('even', function()
    local cur = assert.is_table(r.run(r.reql_table.changes().filter(
      function(row)
        return (row'new_val''id' % 2).eq(0)
      end
    ).limit(2)))
    assert.is_table(r.run(r.reql_table.insert(
      {{id = 7}, {id = 8}, {id = 9}, {id = 10}}
    ))).to_array()
    local res = {}
    cur.each(function(row)
      table.insert(res, row.new_val.id)
    end, function(err)
      assert.is_nil(err)
    end)
    table.sort(res)
    assert.same(res, {8, 10})
  end)
end)
