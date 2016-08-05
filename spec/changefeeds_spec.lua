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

    function r.run(query, ...)
      assert.is_table(query, ...)
      return assert.is_table(query.run(query.r.c))
    end

    r.reql_db = r.reql.db'changefeeds'
    r.reql_table = r.reql.table'watched'

    r.c = assert.is_table(r.connect())

    r.run(r.reql.db_create'changefeeds').to_array()
    r.c.use'changefeeds'
    r.run(r.reql.table_create'watched').to_array()
  end)

  before_each(function()
    r.run(r.reql_table.insert{
      {id = 1}, {id = 2}, {id = 3},
      {id = 4}, {id = 5}, {id = 6}
    }).to_array()
  end)

  after_each(function()
    r.run(r.reql_table.delete()).to_array()
  end)

  teardown(function()
    r = nil
    assert:remove_formatter(reql_error_formatter)
  end)

  it('all', function()
    local cur = r.run(r.reql_table.changes().limit(4))
    r.run(r.reql_table.insert{
      {id = 7}, {id = 8}, {id = 9}, {id = 10}
    }).to_array()
    local res = {}
    for i, v in cur.each() do
      assert.is_not_equal(0, i, v)
      res[i] = v.new_val.id
    end
    table.sort(res)
    assert.same({7, 8, 9, 10}, res)
  end)

  it('even', function()
    local cur = r.run(r.reql_table.changes().filter(
      function(row)
        return (row'new_val''id' % 2).eq(0)
      end
    ).limit(2))
    r.run(r.reql_table.insert{
      {id = 7}, {id = 8}, {id = 9}, {id = 10}
    }).to_array()
    local res = {}
    for i, v in cur.each() do
      assert.is_not_equal(0, i, v)
      res[i] = v.new_val.id
    end
    table.sort(res)
    assert.same(res, {8, 10})
  end)
end)
